#!/bin/bash
set -e

SERVICE_NAME="godot-server"

echo "🔄 Перезагружаем systemd (daemon-reload)..."
sudo systemctl daemon-reload

echo "🔌 Включаем автозапуск $SERVICE_NAME..."
sudo systemctl enable $SERVICE_NAME

echo "▶️  Запускаем $SERVICE_NAME..."
sudo systemctl restart $SERVICE_NAME

echo "✅ Готово! Статус:"
sudo systemctl status $SERVICE_NAME --no-pager