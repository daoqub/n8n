#!/bin/bash
set -e

# Цвета
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Проверка root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Запустите с sudo${NC}"
  exit 1
fi

# ========== Ввод параметров ==========
echo -e "${YELLOW}📋 Введите параметры установки${NC}"

# Email для SSL/уведомлений
while true; do
  read -p "📧 Email: " USER_EMAIL
  if [[ "$USER_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then break; fi
  echo -e "${RED}Неверный формат${NC}"
done

# Пароль PostgreSQL
while true; do
  read -sp "🔐 Пароль PostgreSQL (мин. 8 символов): " DB_PASSWORD
  echo
  [ ${#DB_PASSWORD} -ge 8 ] || { echo -e "${RED}Слишком короткий${NC}"; continue; }
  read -sp "🔐 Повторите пароль: " DB_PASSWORD2
  echo
  [ "$DB_PASSWORD" = "$DB_PASSWORD2" ] && break
  echo -e "${RED}Пароли не совпали${NC}"
done

# Выбор SSL
echo -e "${YELLOW}🔒 Выберите режим SSL${NC}"
echo "  1) Let’s Encrypt (требует домен и DNS)"
echo "  2) Самоподписанный (10 лет)"
echo "  3) Без SSL (HTTP по IP:5678)"
read -p "Выберите [1-3]: " SSL_CHOICE
case "$SSL_CHOICE" in
  1) SSL_MODE="letsencrypt";;
  2) SSL_MODE="selfsigned";;
  3) SSL_MODE="none";;
  *) echo -e "${RED}Неверный выбор, используется без SSL${NC}"; SSL_MODE="none";;
esac

# Запрашиваем домен только для SSL
if [ "$SSL_MODE" != "none" ]; then
  read -p "🌐 Домен (например n8n.example.ru): " USER_DOMAIN
fi

# ========== Установка Docker ==========
apt update -qq
apt install -y docker.io docker-compose curl openssl >/dev/null 2>&1
systemctl enable --now docker

# ========== Подготовка папок ==========
mkdir -p /opt/n8n/{postgres,data,certs}
cd /opt/n8n

# ========== Самоподписанный SSL ==========
if [ "$SSL_MODE" = "selfsigned" ]; then
  echo -e "${GREEN}🔐 Генерация самоподписанного сертификата...${NC}"
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout certs/selfsigned.key \
    -out certs/selfsigned.crt \
    -subj "/CN=${USER_DOMAIN}" >/dev/null 2>&1
fi

# ========== Внешний IP ==========
EXTERNAL_IP=$(curl -s ifconfig.me || echo "127.0.0.1")

# ========== Создание docker-compose.yml ==========
cat > docker-compose.yml <<EOF
version: '3.8'

networks:
  n8n-network:

volumes:
  postgres_data:
  n8n_data:
EOF

if [ "$SSL_MODE" != "none" ]; then
  cat >> docker-compose.yml <<EOF
  nginx_certs:
  nginx_vhost:
  nginx_html:
EOF
fi

cat >> docker-compose.yml <<EOF

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
    networks:
      - n8n-network

EOF

if [ "$SSL_MODE" = "none" ]; then
  cat >> docker-compose.yml <<EOF
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "5678:5678"
    environment:
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
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
    networks:
      - n8n-network

EOF
else
  cat >> docker-compose.yml <<EOF
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

EOF

  if [ "$SSL_MODE" = "letsencrypt" ]; then
    cat >> docker-compose.yml <<EOF
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

EOF
  fi

  cat >> docker-compose.yml <<EOF
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      - VIRTUAL_HOST=${USER_DOMAIN}
      - VIRTUAL_PORT=5678
EOF

  if [ "$SSL_MODE" = "letsencrypt" ]; then
    cat >> docker-compose.yml <<EOF
      - LETSENCRYPT_HOST=${USER_DOMAIN}
      - LETSENCRYPT_EMAIL=${USER_EMAIL}
EOF
  fi

  cat >> docker-compose.yml <<EOF
      - N8N_HOST=${USER_DOMAIN}
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - WEBHOOK_URL=https://${USER_DOMAIN}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD="${DB_PASSWORD}"
      - GENERIC_TIMEZONE=Europe/Moscow
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network

EOF
fi

# ========== Открытие портов ==========
if command -v ufw &>/dev/null; then
  if [ "$SSL_MODE" = "none" ]; then
    ufw allow 5678/tcp >/dev/null 2>&1
  else
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    ufw allow 5678/tcp >/dev/null 2>&1
  fi
fi

# ========== Запуск и перезагрузка ==========
docker-compose up -d
echo -e "${GREEN}🚀 Контейнеры запущены${NC}"
docker-compose restart
echo -e "${GREEN}🔄 Контейнеры перезагружены${NC}"

# ========== Сохранение учётных данных ==========
cat > /opt/n8n/PASSWORDS.txt <<EOF
УЧЁТНЫЕ ДАННЫЕ:
Email: ${USER_EMAIL}
Пароль PostgreSQL: ${DB_PASSWORD}

Доступ:
EOF

if [ "$SSL_MODE" = "none" ]; then
  cat >> /opt/n8n/PASSWORDS.txt <<EOF
  http://${EXTERNAL_IP}:5678
EOF
else
  cat >> /opt/n8n/PASSWORDS.txt <<EOF
  https://${USER_DOMAIN}
EOF
fi

chmod 600 /opt/n8n/PASSWORDS.txt
echo -e "${GREEN}✅ Пароли сохранены в /opt/n8n/PASSWORDS.txt${NC}"
echo -e "${GREEN}🌐 Откройте в браузере: http://${EXTERNAL_IP}:5678${NC}"

