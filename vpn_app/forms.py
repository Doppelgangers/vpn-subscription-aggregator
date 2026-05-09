from django import forms
from .models import AggregateSubscription, SourceLink

class AggregateSubscriptionForm(forms.ModelForm):
    class Meta:
        model = AggregateSubscription
        fields = ['name', 'token', 'custom_base_url']
        widgets = {
            'name': forms.TextInput(attrs={
                'class': 'w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition',
                'placeholder': 'Например: Мои сервера Европа'
            }),
            'token': forms.TextInput(attrs={
                'class': 'w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition font-mono text-sm',
                'placeholder': 'Уникальный токен или UUID'
            }),
            'custom_base_url': forms.TextInput(attrs={
                'class': 'w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition',
                'placeholder': 'subses.doppelgangeres.com:5090'
            })
        }


class SourceLinkForm(forms.ModelForm):
    class Meta:
        model = SourceLink
        fields = ['url', 'is_active']
        widgets = {
            'url': forms.URLInput(attrs={
                'class': 'w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition',
                'placeholder': 'https://ip:port/sub/...'
            }),
            'is_active': forms.CheckboxInput(attrs={'class': 'w-5 h-5 text-blue-600 rounded focus:ring-blue-500'})
        }
