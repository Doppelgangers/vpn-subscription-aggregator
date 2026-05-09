#!/bin/bash

# Скрипт автоматического деплоя (Интерактивный)

# 1. Определяем пути
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

echo "--- Настройка параметров деплоя ---"
read -p "Введите домен или IP сервера (например, example.com или 1.2.3.4): " SERVER_DOMAIN
read -p "Введите порт для Nginx (по умолчанию 80): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-80}

echo "--- Starting Deployment as $CURRENT_USER ---"
echo "Project directory: $PROJECT_DIR"
echo "Domain: $SERVER_DOMAIN"
echo "Port: $SERVER_PORT"

# 2. Установка системных зависимостей
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv nginx curl

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
# Удаляем дефолтный конфиг только если мы на 80 порту
if [ "$SERVER_PORT" == "80" ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# 7. Перезапуск всего
echo "Restarting services..."
sudo systemctl daemon-reload
sudo systemctl enable --now vpn-aggregator.socket
sudo systemctl restart vpn-aggregator.service

sudo nginx -t && sudo systemctl restart nginx

echo "--- Deployment Finished ---"
echo "Your app should be available at http://$SERVER_DOMAIN:$SERVER_PORT"
