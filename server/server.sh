#!/bin/bash
set -e

SERVICE_NAME="godot-server"
ACTION="$1"

case "$ACTION" in
    start)
        echo "▶️  Запускаем $SERVICE_NAME..."
        sudo systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "⏹  Останавливаем $SERVICE_NAME..."
        sudo systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "🔄 Перезапускаем $SERVICE_NAME..."
        sudo systemctl restart $SERVICE_NAME
        ;;
    status)
        sudo systemctl status $SERVICE_NAME --no-pager
        exit 0
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        exit 0
        ;;
    setup)
        echo "⚙️  Настраиваем и запускаем $SERVICE_NAME..."
        sudo systemctl daemon-reload
        sudo systemctl enable $SERVICE_NAME
        sudo systemctl restart $SERVICE_NAME
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|logs|setup}"
        exit 1
        ;;
esac

echo "✅ Готово! Статус:"
sudo systemctl status $SERVICE_NAME --no-pager