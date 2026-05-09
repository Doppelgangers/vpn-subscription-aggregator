# VPN Subscription Aggregator (Хаб подписок XRAY)

Мощный и легкий агрегатор для управления подписками XRAY. Объединяет десятки ссылок от панелей 3x-ui в одну "вечную" ссылку, решая проблему частой смены IP серверов.

## Основные возможности
- **Умная агрегация:** Собирает конфиги (VLESS, VMESS, Trojan, SS) из нескольких источников в один поток.
- **Статистика трафика:** Автоматически суммирует Upload/Download трафик со всех нод и передает его клиенту (v2rayTun, v2rayNG и др.).
- **Поддержка Кириллицы:** Использует стандарт `base64:` в заголовках, гарантируя корректное отображение русских названий подписок.
- **Отказоустойчивость:** Автоматически фильтрует нерабочие узлы и сервера с таймаутом (3 сек), обеспечивая мгновенный ответ.
- **Custom UI:** Современный дашборд на Tailwind CSS для управления без использования админки Django.
- **SSL "из коробки":** Автоматическая настройка HTTPS через Certbot даже на кастомных портах (напр. 5090).

## Как это работает (Архитектура)
1. Клиент делает запрос на `https://domain:port/sub/<token>/`.
2. Хаб находит в БД список привязанных к токену ссылок.
3. Хаб параллельно (с таймаутом 3с) опрашивает все активные ссылки.
4. Хаб извлекает конфиги и суммирует данные о трафике из заголовков `Subscription-Userinfo`.
5. Хаб формирует ответ с заголовками `profile-title` (имя подписки) и `Subscription-Userinfo` (статистика).
6. Ответ кодируется в Base64 и отдается клиенту.

## Быстрый старт (Локально)
```bash
git clone https://github.com/Doppelgangers/vpn-subscription-aggregator.git
cd vpn-subscription-aggregator
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```
Создайте администратора: `python manage.py createsuperuser`

## Деплой (Production)
Для деплоя на Ubuntu/Debian с поддержкой SSL на порту 5090:
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```
Скрипт сам установит Nginx, Certbot, настроит системные сервисы и создаст аккаунт администратора.

## Стек технологий
- **Backend:** Django 4.2 (Python 3.11+)
- **Frontend:** Tailwind CSS, Lucide Icons
- **Web Server:** Nginx + Gunicorn
- **Database:** SQLite (легковесность и портативность)
