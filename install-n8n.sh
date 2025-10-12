#!/bin/bash
set -e

# Цвета
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Проверка root
if [ "$EUID" -ne 0 ]; then echo -e "${RED}❌ Запустите sudo bash $0${NC}"; exit 1; fi

# Параметры
USER_EMAIL="sheepoff@gmail.com"
USER_DOMAIN="grouchily.ru"
DB_PASSWORD="*V8u2p2rRya8"

# Установка Docker
apt update -qq
apt install -y docker.io docker-compose curl openssl >/dev/null 2>&1
systemctl enable --now docker

# Подготовка папок
mkdir -p /opt/n8n/{postgres,data,certs}
cd /opt/n8n

# Генерация самоподписанного SSL на случай теста
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout certs/selfsigned.key \
  -out certs/selfsigned.crt \
  -subj "/CN=$USER_DOMAIN" >/dev/null 2>&1

# Создание docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'

networks:
  n8n-network:

volumes:
  postgres_data:
  n8n_data:
  nginx_certs:
  nginx_vhost:
  nginx_html:

services:
  # nginx-proxy для домена
  nginx-proxy:
    image: nginxproxy/nginx-proxy:alpine
    container_name: nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - nginx_certs:/etc/nginx/certs
      - nginx_vhost:/etc/nginx/vhost.d
      - nginx_html:/usr/share/nginx/html
    networks:
      - n8n-network

  # companion для Let's Encrypt
  acme-companion:
    image: nginxproxy/acme-companion
    container_name: acme-companion
    restart: unless-stopped
    depends_on:
      - nginx-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nginx_certs:/etc/nginx/certs
      - nginx_vhost:/etc/nginx/vhost.d
      - nginx_html:/usr/share/nginx/html
      - /etc/acme.sh:/etc/acme.sh
    networks:
      - n8n-network
    environment:
      - DEFAULT_EMAIL=${USER_EMAIL}
      - NGINX_PROXY_CONTAINER=nginx-proxy

  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-network

  # n8n
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_started
    environment:
      # Доступ по IP
      - N8N_PROTOCOL=http
      - N8N_PORT=5678
      - WEBHOOK_URL=http://\${EXTERNAL_IP}:5678/
      # Доступ по домену
      - VIRTUAL_HOST=${USER_DOMAIN}
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=${USER_DOMAIN}
      - LETSENCRYPT_EMAIL=${USER_EMAIL}
      - N8N_HOST=${USER_DOMAIN}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${USER_DOMAIN}/
      # Общие
      - GENERIC_TIMEZONE=Europe/Moscow
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network

EOF

# Добавить внешний IP в переменные для compose
EXTERNAL_IP=$(curl -s ifconfig.me)
sed -i "s/\${EXTERNAL_IP}/$EXTERNAL_IP/g" docker-compose.yml

# Открыть порты в UFW (если включён)
command -v ufw &>/dev/null && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 5678/tcp

# Запуск
docker-compose up -d

# Инструкция по DNS выводим в файл
cat > DNS_INSTRUCTION.txt <<TXT
Чтобы подключить домен ${USER_DOMAIN}:
1. В Google Cloud DNS создайте A-запись:
   ${USER_DOMAIN} → ${EXTERNAL_IP}
2. В разделе Cloud DNS вы увидите NS-записи вида:
   ns-cloud-<x>1.googledomains.com.
   ns-cloud-<x>2.googledomains.com.
   ns-cloud-<x>3.googledomains.com.
   ns-cloud-<x>4.googledomains.com.
3. На сайте регистратора замените NS на эти четыре записи.
TXT

chmod 600 DNS_INSTRUCTION.txt

echo -e "${GREEN}Установка завершена!${NC}"
echo "• N8N по IP: http://$EXTERNAL_IP:5678"
echo "• N8N по домену: https://$USER_DOMAIN (после DNS)"
echo "Инструкция по DNS: DNS_INSTRUCTION.txt"
