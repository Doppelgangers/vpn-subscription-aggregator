#!/bin/bash

# Скрипт автоматического деплоя для vpn-subscription-aggregator
# Предполагается, что проект лежит в /home/www/vpn-subscription-aggregator

PROJECT_DIR="/home/www/vpn-subscription-aggregator"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_DIR="/etc/nginx/sites-available"

echo "--- Starting Deployment ---"

# 1. Стягиваем последние изменения (если нужно)
# git pull origin main

# 2. Установка зависимостей
cd $PROJECT_DIR
source env/bin/activate
pip install -r requirements.txt

# 3. Миграции и статика
python manage.py migrate
python manage.py collectstatic --noinput

# 4. Копирование systemd файлов
sudo cp deploy/systemd/vpn-aggregator.socket $SYSTEMD_DIR/
sudo cp deploy/systemd/vpn-aggregator.service $SYSTEMD_DIR/

# 5. Настройка Nginx
sudo cp deploy/nginx/vpn-aggregator.conf $NGINX_DIR/
sudo ln -sf $NGINX_DIR/vpn-aggregator.conf /etc/nginx/sites-enabled/

# 6. Перезапуск сервисов
sudo systemctl daemon-reload
sudo systemctl start vpn-aggregator.socket
sudo systemctl enable vpn-aggregator.socket
sudo systemctl restart vpn-aggregator.service

# 7. Проверка Nginx
sudo nginx -t && sudo systemctl restart nginx

echo "--- Deployment Finished ---"
echo "Check status: systemctl status vpn-aggregator.service"
