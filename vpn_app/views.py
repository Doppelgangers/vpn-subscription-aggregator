import base64
import requests
import logging
import urllib3
from django.shortcuts import render, get_object_or_404, redirect
from django.http import HttpResponse
from django.contrib.auth.decorators import login_required
from .models import AggregateSubscription, SourceLink
from .forms import AggregateSubscriptionForm, SourceLinkForm

# Silence InsecureRequestWarning for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger(__name__)

def aggregate_sub_view(request, token):
    agg_sub = get_object_or_404(AggregateSubscription, token=token)
    all_configs = []
    total_upload = 0
    total_download = 0
    
    active_links = agg_sub.links.filter(is_active=True)
    
    for source in active_links:
        try:
            # Reduced timeout to 3s to keep the hub responsive when a node is down
            response = requests.get(source.url, timeout=3, verify=False)
            if response.status_code == 200:
                # Читаем заголовки трафика от 3x-ui если они есть
                sub_info = response.headers.get('Subscription-Userinfo', '')
                if sub_info:
                    try:
                        # Формат: upload=...; download=...; total=...; expire=...
                        info_parts = dict(item.split('=') for item in sub_info.split('; ') if '=' in item)
                        total_upload += int(info_parts.get('upload', 0))
                        total_download += int(info_parts.get('download', 0))
                    except: pass

                raw_text = response.text.strip()
                if not raw_text:
                    continue
                
                # 3x-ui typically returns a base64 string
                try:
                    # Fix padding if necessary
                    missing_padding = len(raw_text) % 4
                    if missing_padding:
                        raw_text += '=' * (4 - missing_padding)
                    
                    decoded_bytes = base64.b64decode(raw_text)
                    decoded_content = decoded_bytes.decode('utf-8')
                    configs = decoded_content.strip().split('\n')
                except Exception:
                    # Fallback to raw text if base64 decode fails
                    configs = raw_text.split('\n')
                
                for config in configs:
                    clean_config = config.strip()
                    if clean_config and any(clean_config.startswith(p) for p in ['vless://', 'vmess://', 'trojan://', 'ss://']):
                        all_configs.append(clean_config)
        except Exception as e:
            logger.error(f"Failed to fetch {source.url}: {e}")
            continue
            
    if not all_configs:
        return HttpResponse("No configs found or all nodes are down", status=404)

    final_content = "\n".join(all_configs)
    encoded_content = base64.b64encode(final_content.encode('utf-8')).decode('utf-8')
    
    response = HttpResponse(encoded_content, content_type="text/plain; charset=utf-8")
    
    # Определяем название подписки (приоритет полю client_title)
    sub_display_name = agg_sub.client_title or agg_sub.name

    # Добавляем название подписки для приложений (v2rayTun и др)
    # Используем прямой текст, так как многие клиенты не декодируют Base64 здесь
    response['profile-title'] = sub_display_name
    
    # Дополнительный заголовок для совместимости
    response['Content-Disposition'] = f'attachment; filename="{sub_display_name}.txt"'
    
    # Добавляем информацию о трафике (суммарную)
    # total=0 означает безлимит в большинстве клиентов
    response['Subscription-Userinfo'] = f"upload={total_upload}; download={total_download}; total=0; expire=0"
    
    return response

@login_required
def dashboard(request):
    subscriptions = AggregateSubscription.objects.all()
    return render(request, 'vpn_app/dashboard.html', {'subscriptions': subscriptions})

@login_required
def create_subscription(request):
    if request.method == 'POST':
        form = AggregateSubscriptionForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('dashboard')
    else:
        form = AggregateSubscriptionForm()
    return render(request, 'vpn_app/sub_form.html', {'form': form, 'title': 'Новая подписка'})

@login_required
def edit_subscription(request, pk):
    sub = get_object_or_404(AggregateSubscription, pk=pk)
    if request.method == 'POST':
        form = AggregateSubscriptionForm(request.POST, instance=sub)
        if form.is_valid():
            form.save()
            return redirect('dashboard')
    else:
        form = AggregateSubscriptionForm(instance=sub)
    
    links = sub.links.all()
    return render(request, 'vpn_app/sub_edit.html', {'form': form, 'sub': sub, 'links': links})

from django.utils import timezone

def validate_and_update_link(link):
    try:
        response = requests.get(link.url, timeout=5, verify=False)
        link.last_status_code = response.status_code
        link.last_checked = timezone.now()
        
        if response.status_code == 200:
            raw_text = response.text.strip()
            # Try decode
            try:
                # Fix padding
                rem = len(raw_text) % 4
                if rem: raw_text += "=" * (4 - rem)
                decoded = base64.b64decode(raw_text).decode('utf-8')
                configs = decoded.strip().split('\n')
            except:
                configs = raw_text.split('\n')
            
            valid_configs = [c.strip() for c in configs if any(c.strip().startswith(p) for p in ['vless://', 'vmess://', 'trojan://', 'ss://'])]
            link.config_count = len(valid_configs)
            if link.config_count > 0:
                link.error_message = ""
                link.is_active = True
            else:
                link.error_message = "Конфиги не найдены"
        else:
            link.config_count = 0
            link.error_message = f"HTTP {response.status_code}"
    except Exception as e:
        link.last_status_code = 0
        link.config_count = 0
        link.error_message = str(e)
        link.last_checked = timezone.now()
    
    link.save()

@login_required
def add_link(request, sub_pk):
    sub = get_object_or_404(AggregateSubscription, pk=sub_pk)
    if request.method == 'POST':
        url = request.POST.get('url')
        remark = request.POST.get('remark', '')
        if url:
            link = SourceLink.objects.create(subscription=sub, url=url, remark=remark)
            validate_and_update_link(link)
    return redirect('edit_subscription', pk=sub_pk)

from django.contrib import messages

@login_required
def delete_link(request, link_pk):
    link = get_object_or_404(SourceLink, pk=link_pk)
    sub_pk = link.subscription.pk
    link.delete()
    messages.success(request, 'Источник удален')
    return redirect('edit_subscription', pk=sub_pk)

@login_required
def delete_subscription(request, pk):
    sub = get_object_or_404(AggregateSubscription, pk=pk)
    sub.delete()
    messages.success(request, 'Агрегатор удален')
    return redirect('dashboard')

@login_required
def toggle_link(request, link_pk):
    link = get_object_or_404(SourceLink, pk=link_pk)
    link.is_active = not link.is_active
    link.save()
    status = "включен" if link.is_active else "выключен"
    messages.success(request, f'Источник {status}')
    return redirect('edit_subscription', pk=link.subscription.pk)

@login_required
def check_link(request, link_pk):
    link = get_object_or_404(SourceLink, pk=link_pk)
    validate_and_update_link(link)
    messages.success(request, 'Статус обновлен')
    return redirect('edit_subscription', pk=link.subscription.pk)

def index(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    return render(request, 'vpn_app/index.html')
