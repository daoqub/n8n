#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Автоустановка N8N + Docker + SSL    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Запустите: sudo bash install-n8n.sh${NC}"
    exit 1
fi

# ========== ПЕРЕМЕННЫЕ ==========
USER_EMAIL="sheepoff@gmail.com"
USER_DOMAIN="grouchily.ru"
DB_PASSWORD="*V8u2p2rRya8"

# ========== ВЫБОР РЕЖИМА ==========
echo -e "${YELLOW}🔒 Выберите режим SSL:${NC}"
echo "  1) Let's Encrypt (требует настройки DNS)"
echo "  2) Самоподписанный сертификат (10 лет)"
echo "  3) Без SSL - доступ по IP:5678 (быстрый старт)"
echo ""
read -p "Выберите (1/2/3): " SSL_CHOICE

case $SSL_CHOICE in
    1) SSL_MODE="letsencrypt";;
    2) SSL_MODE="selfsigned";;
    3) SSL_MODE="none";;
    *) echo -e "${RED}Выберите 1, 2 или 3${NC}"; exit 1;;
esac

echo -e "${GREEN}✅ Выбран режим: $SSL_MODE${NC}"

# ========== УСТАНОВКА DOCKER ==========
echo ""
echo -e "${GREEN}📦 Установка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    apt update -qq
    apt install -y docker.io docker-compose curl openssl > /dev/null 2>&1
    systemctl start docker && systemctl enable docker > /dev/null 2>&1
    echo -e "${GREEN}✅ Docker установлен${NC}"
else
    echo -e "${GREEN}✅ Docker уже установлен${NC}"
fi

# ========== СОЗДАНИЕ СТРУКТУРЫ ==========
echo ""
echo -e "${GREEN}📁 Создание директорий...${NC}"
mkdir -p /opt/n8n/{postgres,data,certs}
cd /opt/n8n

# ========== ГЕНЕРАЦИЯ СЕРТИФИКАТА (если нужно) ==========
if [ "$SSL_MODE" == "selfsigned" ]; then
    echo -e "${GREEN}🔐 Генерация SSL-сертификата (10 лет)...${NC}"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /opt/n8n/certs/$USER_DOMAIN.key \
        -out /opt/n8n/certs/$USER_DOMAIN.crt \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=N8N/CN=$USER_DOMAIN" \
        > /dev/null 2>&1
    echo -e "${GREEN}✅ Сертификат создан${NC}"
fi

# ========== DOCKER-COMPOSE ==========
echo ""
echo -e "${GREEN}📝 Создание docker-compose.yml...${NC}"

if [ "$SSL_MODE" == "none" ]; then
    # Простой режим без SSL - только PostgreSQL + N8N
    cat > docker-compose.yml <<EOF
version: '3.8'

services:
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - N8N_PROTOCOL=http
      - N8N_PORT=5678
      - GENERIC_TIMEZONE=Europe/Moscow
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres_data:
  n8n_data:
EOF

else
    # Режим с SSL (Let's Encrypt или самоподписанный)
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

    if [ "$SSL_MODE" == "letsencrypt" ]; then
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - VIRTUAL_HOST=${USER_DOMAIN}
      - VIRTUAL_PORT=5678
EOF

    if [ "$SSL_MODE" == "letsencrypt" ]; then
        cat >> docker-compose.yml <<EOF
      - LETSENCRYPT_HOST=${USER_DOMAIN}
      - LETSENCRYPT_EMAIL=${USER_EMAIL}
EOF
    fi

    cat >> docker-compose.yml <<EOF
      - N8N_HOST=${USER_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${USER_DOMAIN}/
      - GENERIC_TIMEZONE=Europe/Moscow
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network
EOF

    if [ "$SSL_MODE" == "selfsigned" ]; then
        cat >> docker-compose.yml <<EOF
      - ./certs:/etc/nginx/certs:ro
EOF
    fi

fi

# ========== ОТКРЫТИЕ ПОРТОВ ==========
if command -v ufw &> /dev/null; then
    if [ "$SSL_MODE" == "none" ]; then
        ufw allow 5678/tcp > /dev/null 2>&1
    else
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
    fi
fi

# ========== ЗАПУСК ==========
echo ""
echo -e "${GREEN}🚀 Запуск контейнеров...${NC}"
docker-compose up -d
sleep 15

# Получение внешнего IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "UNKNOWN")

# ========== СОХРАНЕНИЕ ПАРОЛЕЙ ==========
cat > /opt/n8n/PASSWORDS.txt <<PASSWORD_EOF
╔═══════════════════════════════════════════╗
║      УЧЁТНЫЕ ДАННЫЕ N8N УСТАНОВКИ         ║
╚═══════════════════════════════════════════╝

Дата: $(date '+%d.%m.%Y %H:%M')

📧 Email: $USER_EMAIL
🔐 Пароль PostgreSQL: $DB_PASSWORD
🔒 Режим SSL: $SSL_MODE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 ДОСТУП К N8N:
EOF

if [ "$SSL_MODE" == "none" ]; then
    cat >> /opt/n8n/PASSWORDS.txt <<PASSWORD_EOF
   http://$EXTERNAL_IP:5678
   
⚠️  Откройте в Google Cloud Console:
   VPC network → Firewall → Создать правило
   Направление: Входящий трафик
   Цели: Все экземпляры в сети  
   Порты: TCP 5678
PASSWORD_EOF
else
    cat >> /opt/n8n/PASSWORDS.txt <<PASSWORD_EOF
   https://$USER_DOMAIN
   
⚠️  Настройте DNS: A-запись $USER_DOMAIN → $EXTERNAL_IP
PASSWORD_EOF
fi

cat >> /opt/n8n/PASSWORDS.txt <<PASSWORD_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 ВОССТАНОВЛЕНИЕ ПАРОЛЯ:
docker exec -it n8n n8n user-management:reset
docker restart n8n
PASSWORD_EOF

chmod 600 /opt/n8n/PASSWORDS.txt

# ========== ИТОГ ==========
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ✅ УСТАНОВКА ЗАВЕРШЕНА! ✅       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

if [ "$SSL_MODE" == "none" ]; then
    echo -e "${BLUE}🌐 Доступ: ${GREEN}http://$EXTERNAL_IP:5678${NC}"
    echo -e "${YELLOW}⚠️  Откройте в Google Cloud: VPC network → Firewall → TCP 5678${NC}"
else
    echo -e "${BLUE}🌐 Доступ: ${GREEN}https://$USER_DOMAIN${NC}"
    echo -e "${YELLOW}⚠️  Настройте DNS: A-запись $USER_DOMAIN → $EXTERNAL_IP${NC}"
fi

echo -e "${BLUE}💾 Пароли: ${GREEN}/opt/n8n/PASSWORDS.txt${NC}"
echo ""
