#!/bin/bash

# Скрипт автоматического деплоя (Интерактивный + SSL на любом порту)

# 1. Определяем пути
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

echo "--- Настройка параметров деплоя ---"
read -p "Введите домен сервера (напр. sub.example.com): " SERVER_DOMAIN
read -p "Введите порт для этого приложения (напр. 5090): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-5090}

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

# 6. Получение SSL сертификата (если указан домен)
# Используем certonly, чтобы не менять конфиги Nginx автоматически
PROTOCOL="http"
if [[ "$SERVER_DOMAIN" == *"."* ]]; then
    echo "Attempting to get/renew SSL certificate for $SERVER_DOMAIN..."
    # Пытаемся получить сертификат. Если на 80 порту уже есть сайт, Certbot через --nginx сам разберется
    sudo certbot certonly --nginx -d "$SERVER_DOMAIN" --non-interactive --agree-tos -m "admin@$SERVER_DOMAIN"
    
    if [ -f "/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem" ]; then
        PROTOCOL="https"
        echo "SSL Certificate found/obtained!"
    else
        echo "SSL Certificate NOT obtained. Falling back to HTTP."
    fi
fi

# 7. Настройка Nginx
echo "Configuring Nginx..."
if [ "$PROTOCOL" == "https" ]; then
cat <<EOF > vpn-aggregator.conf
server {
    listen $SERVER_PORT ssl;
    server_name $SERVER_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem;

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
else
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
fi

sudo mv vpn-aggregator.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/vpn-aggregator.conf /etc/nginx/sites-enabled/

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

echo -e "\n\e[1;32m--- Deployment Finished Successfully ---\e[0m"
echo -e "\e[1;34mПанель управления доступна по адресу:\e[0m"
echo -e "URL: \e[1;36m$PROTOCOL://$SERVER_DOMAIN:$SERVER_PORT\e[0m"
echo -e "Админка: \e[1;36m$PROTOCOL://$SERVER_DOMAIN:$SERVER_PORT/dashboard/\e[0m"
echo -e "\n\e[1;33mДанные для входа:\e[0m"
echo -e "Логин:  \e[1;32m$ADMIN_USER\e[0m"
echo -e "Пароль: \e[1;32m$ADMIN_PASS\e[0m"
echo -e "\n\e[1;31mВНИМАНИЕ:\e[0m Обязательно сохраните эти данные!"
echo -e "----------------------------------------"
