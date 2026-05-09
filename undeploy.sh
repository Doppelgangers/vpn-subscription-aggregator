#!/bin/bash

# Скрипт удаления (undeploy) для vpn-subscription-aggregator
# Очищает системные файлы systemd и nginx

APP_NAME="vpn-aggregator"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

echo "--- Starting Undeployment (Cleanup) ---"

# 1. Останавливаем и отключаем сервисы
echo "Stopping services..."
sudo systemctl stop $APP_NAME.service
sudo systemctl stop $APP_NAME.socket
sudo systemctl disable $APP_NAME.service
sudo systemctl disable $APP_NAME.socket

# 2. Удаляем файлы systemd
echo "Removing systemd units..."
sudo rm -f $SYSTEMD_DIR/$APP_NAME.service
sudo rm -f $SYSTEMD_DIR/$APP_NAME.socket
sudo systemctl daemon-reload

# 3. Удаляем конфиги Nginx
echo "Removing Nginx configuration..."
sudo rm -f $NGINX_ENABLED/$APP_NAME.conf
sudo rm -f $NGINX_AVAILABLE/$APP_NAME.conf

# 4. Перезапуск Nginx для применения изменений
sudo nginx -t && sudo systemctl restart nginx

echo "--- Cleanup Finished ---"
echo "Systemd units and Nginx configs for $APP_NAME have been removed."
