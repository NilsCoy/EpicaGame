#!/bin/bash
set -e

SERVICE_NAME="godot-server"

echo "⏹  Останавливаем $SERVICE_NAME..."
sudo systemctl stop $SERVICE_NAME

echo "✅ Готово!"