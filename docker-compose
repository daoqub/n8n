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
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: "n8n"
      POSTGRES_USER: "n8n"
      POSTGRES_PASSWORD: "*********"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-network

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
    environment:
      - DEFAULT_EMAIL=********
      - NGINX_PROXY_CONTAINER=nginx-proxy
    networks:
      - n8n-network

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      - VIRTUAL_HOST=grouchily.ru
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=grouchily.ru
      - LETSENCRYPT_EMAIL=*******
      - N8N_PROTOCOL=https
      - N8N_HOST=grouchily.ru
      - N8N_PORT=5678
      - WEBHOOK_URL=https://grouchily.ru/
      - N8N_EDITOR_BASE_URL=https://grouchily.ru/
      - N8N_PUBLIC_API_BASE_URL=https://grouchily.ru/
      - GENERIC_TIMEZONE=Europe/Moscow
      - N8N_SECURITY_TRUST_PROXY=true
      - N8N_SECURE_COOKIE=false
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=********
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network

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
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: "n8n"
      POSTGRES_USER: "n8n"
      POSTGRES_PASSWORD: "******"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-network

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
    environment:
      - DEFAULT_EMAIL=******@gmail.com
      - NGINX_PROXY_CONTAINER=nginx-proxy
    networks:
      - n8n-network

  n8n:
    build: .
    image: custom-n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      - VIRTUAL_HOST=grouchily.ru
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=grouchily.ru
      - LETSENCRYPT_EMAIL=*******@gmail.com
      - N8N_PROTOCOL=https
      - N8N_HOST=grouchily.ru
      - N8N_PORT=5678
      - WEBHOOK_URL=https://grouchily.ru/
      - N8N_EDITOR_BASE_URL=https://grouchily.ru/
      - N8N_PUBLIC_API_BASE_URL=https://grouchily.ru/
      - GENERIC_TIMEZONE=Europe/Moscow
      - N8N_SECURITY_TRUST_PROXY=true
      - N8N_SECURE_COOKIE=false
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=*******
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network
