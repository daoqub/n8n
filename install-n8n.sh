#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# Проверка root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Запустите: sudo bash install-n8n.sh${NC}"
  exit 1
fi

# Параметры
USER_EMAIL="sheepoff@gmail.com"
USER_DOMAIN="grouchily.ru"
DB_PASSWORD="V8u2p2rRya8"
SSL_MODE="none"  # без SSL по умолчанию

# Установка Docker
apt update -qq
apt install -y docker.io docker-compose curl openssl >/dev/null 2>&1
systemctl enable --now docker

# Папки
mkdir -p /opt/n8n/{postgres,data}
cd /opt/n8n

# Внешний IP
EXTERNAL_IP=$(curl -s ifconfig.me || echo "127.0.0.1")

# Создание docker-compose.yml (без SSL)
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: "n8n"
      POSTGRES_USER: "n8n"
      POSTGRES_PASSWORD: "${DB_PASSWORD}"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD="${DB_PASSWORD}"
      - N8N_PROTOCOL=http
      - N8N_PORT=5678
      - WEBHOOK_URL=http://${EXTERNAL_IP}:5678/
      - GENERIC_TIMEZONE=Europe/Moscow
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres_data:
  n8n_data:
EOF

# Открытие порта 5678
if command -v ufw &>/dev/null; then
  ufw allow 5678/tcp >/dev/null 2>&1
fi

# Запуск
docker-compose up -d

# Сохранение данных
cat > /opt/n8n/PASSWORDS.txt <<EOF
УЧЁТНЫЕ ДАННЫЕ:
Email: ${USER_EMAIL}
Пароль PostgreSQL: ${DB_PASSWORD}

Доступ по IP:
http://${EXTERNAL_IP}:5678

Чтобы подключить домен и SSL:
1. Настройте A-запись ${USER_DOMAIN} → ${EXTERNAL_IP}
2. Добавьте поддержку SSL через обновлённый скрипт с nginx-proxy
EOF

chmod 600 /opt/n8n/PASSWORDS.txt

echo -e "${GREEN}✅ Установка завершена!${NC}"
echo "-  Пароли: /opt/n8n/PASSWORDS.txt"
echo "-  Доступ: http://${EXTERNAL_IP}:5678"

[1](https://raw.githubusercontent.com/daoqub/n8n/main/install-n8n.sh)
