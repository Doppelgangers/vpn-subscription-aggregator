# VPN Subscription Aggregator (Хаб подписок XRAY)

Мощный и легкий агрегатор для управления подписками XRAY. Объединяйте десятки ссылок от панелей 3x-ui в одну "вечную" ссылку.

## Основные возможности
- **Агрегация:** Собирает конфиги (VLESS, VMESS, Trojan, SS) из нескольких источников в один поток.
- **Стабильность:** Автоматически фильтрует нерабочие узлы и сервера с таймаутом.
- **Custom UI:** Удобный дашборд для управления без использования админки Django.
- **Валидация:** Проверка ссылок в реальном времени с отображением количества конфигов и ошибок.
- **Гибкость:** Возможность задавать свои UUID/токены для ссылок.

## Быстрый старт (Локально)

1. **Установка:**
   ```bash
   git clone https://github.com/Doppelgangers/vpn-subscription-aggregator.git
   cd vpn-subscription-aggregator
   python3 -m venv env
   source env/bin/activate
   pip install -r requirements.txt
   ```

2. **Запуск:**
   ```bash
   python manage.py migrate
   python manage.py runserver
   ```

3. **Админка:** Создайте суперпользователя `python manage.py createsuperuser` для входа в дашборд.

## Деплой (Production)

Для деплоя на Ubuntu/Debian используйте готовый скрипт:
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```
Конфигурационные файлы для `systemd` и `Nginx` находятся в папке `deploy/`.

## Дизайн-код
- **Стек:** Django 4.2, Tailwind CSS, Lucide Icons.
- **Стиль:** Современный Slate/Blue интерфейс с Toast-уведомлениями и модальными окнами.
