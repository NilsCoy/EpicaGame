#!/bin/bash
set -e

SERVICE_NAME="godot-server"

echo "📜 Логи $SERVICE_NAME (Ctrl+C для выхода)..."
journalctl -u $SERVICE_NAME -f