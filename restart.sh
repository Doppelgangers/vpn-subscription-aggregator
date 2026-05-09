#!/bin/bash

# Скрипт быстрой перезагрузки сервисов
# Удобно использовать после git pull

echo "--- Restarting VPN Aggregator Services ---"

# 1. Перезапуск systemd сервисов
sudo systemctl daemon-reload
sudo systemctl restart vpn-aggregator.socket
sudo systemctl restart vpn-aggregator.service

# 2. Перезапуск Nginx
sudo nginx -t && sudo systemctl restart nginx

echo "--- Done ---"
systemctl status vpn-aggregator.service --no-pager
