#!/bin/bash
set -e

SERVICE_NAME="godot-server"

echo "🔄 Перезапускаем $SERVICE_NAME..."
sudo systemctl restart $SERVICE_NAME

echo "✅ Статус:"
sudo systemctl status $SERVICE_NAME --no-pager