#!/bin/bash
set -e

cd /opt/n8n

# Скачиваем новый docker-compose.yml с поддержкой nginx-proxy
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/n8n-autoinstall/main/docker-compose-domain.yml \
  -o docker-compose.yml

# Обновляем переменную домена
sed -i "s/YOUR_DOMAIN/${USER_DOMAIN}/g" docker-compose.yml

# Перезапуск
docker-compose pull
docker-compose up -d nginx-proxy acme-companion n8n
