#!/bin/bash

# Скрипт автоматического деплоя (Интерактивный + SSL)

# 1. Определяем пути
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

echo "--- Настройка параметров деплоя ---"
read -p "Введите домен сервера (ОБЯЗАТЕЛЬНО для SSL, напр. sub.example.com): " SERVER_DOMAIN
read -p "Введите порт для Nginx (по умолчанию 80): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-80}

echo "--- Starting Deployment as $CURRENT_USER ---"
echo "Project directory: $PROJECT_DIR"
echo "Domain: $SERVER_DOMAIN"
echo "Port: $SERVER_PORT"

# 2. Установка системных зависимостей
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv nginx curl certbot python3-certbot-nginx

# 3. Настройка виртуального окружения
cd "$PROJECT_DIR"
if [ ! -d "env" ]; then
    echo "Creating virtual environment..."
    python3 -m venv env
fi

source env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# 4. Подготовка Django
echo "Applying migrations and collecting static..."
python manage.py migrate
python manage.py collectstatic --noinput

# 5. Конфигурация systemd
echo "Configuring systemd..."
cat <<EOF > vpn-aggregator.socket
[Unit]
Description=gunicorn socket
[Socket]
ListenStream=/run/vpn-aggregator.sock
[Install]
WantedBy=sockets.target
EOF

cat <<EOF > vpn-aggregator.service
[Unit]
Description=gunicorn daemon
Requires=vpn-aggregator.socket
After=network.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/env/bin/gunicorn \\
    --access-logfile - \\
    --workers 3 \\
    --bind unix:/run/vpn-aggregator.sock \\
    config.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

sudo cp vpn-aggregator.socket /etc/systemd/system/
sudo cp vpn-aggregator.service /etc/systemd/system/
rm vpn-aggregator.socket vpn-aggregator.service

# 6. Настройка Nginx
echo "Configuring Nginx..."
cat <<EOF > vpn-aggregator.conf
server {
    listen $SERVER_PORT;
    server_name $SERVER_DOMAIN;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        alias $PROJECT_DIR/static/;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/vpn-aggregator.sock;
    }
}
EOF

sudo mv vpn-aggregator.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/vpn-aggregator.conf /etc/nginx/sites-enabled/
if [ "$SERVER_PORT" == "80" ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# 7. Получение SSL сертификата (только если порт 80 и указан домен)
PROTOCOL="http"
if [ "$SERVER_PORT" == "80" ] && [[ "$SERVER_DOMAIN" == *"."* ]]; then
    echo "Attempting to get SSL certificate for $SERVER_DOMAIN..."
    sudo certbot --nginx -d "$SERVER_DOMAIN" --non-interactive --agree-tos -m "admin@$SERVER_DOMAIN"
    if [ $? -eq 0 ]; then
        PROTOCOL="https"
    fi
fi

# 8. Перезапуск всего
echo "Restarting services..."
sudo systemctl daemon-reload
sudo systemctl enable --now vpn-aggregator.socket
sudo systemctl restart vpn-aggregator.service

sudo nginx -t && sudo systemctl restart nginx

# 9. Создание/Обновление админа и вывод информации
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 12)

echo "Setting up admin user..."
source env/bin/activate
python manage.py shell <<EOF
from django.contrib.auth.models import User
if User.objects.filter(username='$ADMIN_USER').exists():
    user = User.objects.get(username='$ADMIN_USER')
    user.set_password('$ADMIN_PASS')
    user.save()
else:
    User.objects.create_superuser('$ADMIN_USER', 'admin@example.com', '$ADMIN_PASS')
EOF

PORT_STR=""
if [ "$PROTOCOL" == "http" ] && [ "$SERVER_PORT" != "80" ]; then
    PORT_STR=":$SERVER_PORT"
fi

echo -e "\n\e[1;32m--- Deployment Finished Successfully ---\e[0m"
echo -e "\e[1;34mПанель управления доступна по адресу:\e[0m"
echo -e "URL: \e[1;36m$PROTOCOL://$SERVER_DOMAIN$PORT_STR\e[0m"
echo -e "Админка: \e[1;36m$PROTOCOL://$SERVER_DOMAIN$PORT_STR/dashboard/\e[0m"
echo -e "\n\e[1;33mДанные для входа:\e[0m"
echo -e "Логин:  \e[1;32m$ADMIN_USER\e[0m"
echo -e "Пароль: \e[1;32m$ADMIN_PASS\e[0m"
echo -e "\n\e[1;31mВНИМАНИЕ:\e[0m Обязательно сохраните эти данные!"
echo -e "----------------------------------------"
