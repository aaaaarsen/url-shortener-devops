#!/bin/bash
# setup_filesystem.sh
# Создаёт директории и файлы-примеры для проекта shortener.
# Запускать на целевой VM (Fedora Server) с правами sudo.

set -euo pipefail

BASE_DIR="/opt/shortener"

echo "==> Создание директорий..."
mkdir -p "${BASE_DIR}/pgdata"
mkdir -p "${BASE_DIR}/logs"
mkdir -p "${BASE_DIR}/config"

echo "==> Создание файла манифеста пода (пример)..."
if [ ! -f "${BASE_DIR}/pod.yaml" ]; then
  cat > "${BASE_DIR}/pod.yaml" <<'EOF'
# Копия манифеста пода будет размещена сюда деплой-скриптом CI/CD.
EOF
fi

echo "==> Создание файла окружения (пример)..."
if [ ! -f /etc/shortener.env ]; then
  cat > /etc/shortener.env <<'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=changeme
DB_NAME=shortener
PORT=8080
EOF
  chmod 600 /etc/shortener.env
fi

echo "==> Создание файла логов (пример)..."
touch "${BASE_DIR}/logs/setup.log"
echo "$(date -u +%FT%TZ) filesystem initialized" >> "${BASE_DIR}/logs/setup.log"

echo "==> Готово. Структура:"
find "${BASE_DIR}" -maxdepth 2
echo "/etc/shortener.env"
