```markdown
# Привязка домена к n8n на Google Cloud VPS

Полная пошаговая инструкция для новичков с автоматическим HTTPS и правильной настройкой.

---

## 🎯 Что получится в результате

- n8n доступен по вашему домену через HTTPS  
- Автоматический SSL-сертификат от Let’s Encrypt  
- Никаких ошибок “Connection lost” или mixed-content  
- Стабильная работа WebSocket и API  

---

## 📋 Подготовка

### 1. Зарегистрируйте домен

- Купите домен у любого регистратора: reg.ru, nic.ru, namecheap.com  
- Запишите данные для входа в панель управления DNS  

### 2. Получите статический IP в Google Cloud

1. Перейдите в Google Cloud Console → Compute Engine → External IP addresses  
2. Рядом с вашей VM нажмите **Reserve**  
3. Скопируйте зарезервированный внешний IP  

### 3. Добавьте A-запись у регистратора

- Тип: `A`  
- Имя/Host: `@`  
- Значение: ваш статический IP  
- TTL: оставить по умолчанию  

---

## 🔥 Порты и безопасность

### 4. Откройте порты в Google Cloud Firewall

- Создайте правило на порт 80 (HTTP)  
- Создайте правило на порт 443 (HTTPS)  

### 5. Настройте UFW на VM (опционально)

```
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 6. Отключите системный nginx

```
sudo systemctl stop nginx
sudo systemctl disable nginx
```

---

## 🐳 Docker и n8n

### 7. Установите Docker и Docker Compose

```
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
```

### 8. Создайте рабочую папку и файлы

```
sudo mkdir -p /opt/n8n
cd /opt/n8n
```

#### 8.1. Dockerfile для n8n с утилитами

```
sudo tee Dockerfile > /dev/null << 'EOF'
FROM n8nio/n8n:latest

USER root
RUN apk update \
 && apk add --no-cache yt-dlp ffmpeg sed

USER node
EOF
```

#### 8.2. docker-compose.yml

```
sudo tee docker-compose.yml > /dev/null << 'EOF'
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
      POSTGRES_PASSWORD: "ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ"
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
      - DEFAULT_EMAIL=ВАШ_EMAIL@ДОМЕН.РУ
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
      - VIRTUAL_HOST=ВАШ_ДОМЕН.РУ
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=ВАШ_ДОМЕН.РУ
      - LETSENCRYPT_EMAIL=ВАШ_EMAIL@ДОМЕН.РУ
      - N8N_PROTOCOL=https
      - N8N_HOST=ВАШ_ДОМЕН.РУ
      - N8N_PORT=5678
      - WEBHOOK_URL=https://ВАШ_ДОМЕН.РУ/
      - N8N_EDITOR_BASE_URL=https://ВАШ_ДОМЕН.РУ/
      - N8N_PUBLIC_API_BASE_URL=https://ВАШ_ДОМЕН.РУ/
      - GENERIC_TIMEZONE=Europe/Moscow
      - N8N_SECURITY_TRUST_PROXY=true
      - N8N_SECURE_COOKIE=false
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network
EOF
```

> **Важно:** замените `ВАШ_ДОМЕН.РУ`, `ВАШ_EMAIL@ДОМЕН.РУ` и `ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ` на ваши значения.

### 9. Запуск контейнеров

```
sudo docker-compose build n8n
sudo docker-compose up -d
```

### 10. Проверка статуса

```
sudo docker-compose ps
```
Все сервисы должны быть в состоянии “Up”.

---

## ✅ Проверка и тестирование HTTPS

### 11. Логи ACME companion

```
sudo docker-compose logs acme-companion
```
Дождитесь успешного запроса сертификата.

### 12. Откройте браузер

Перейдите на https://ВАШ_ДОМЕН.РУ  
— должен загрузиться интерфейс n8n с зелёным замочком.

---

## 🚨 Решение типичных проблем

- **Port 443 already in use**  
  ```
  sudo systemctl stop nginx
  sudo systemctl disable nginx
  sudo docker-compose up -d
  ```
- **Connection lost** — проверьте, что все URL в ENV содержат `https://ВАШ_ДОМЕН.РУ`.  
- **Mixed content blocked** — убедитесь, что `N8N_EDITOR_BASE_URL` и `N8N_PUBLIC_API_BASE_URL` начинаются с `https`.  
- **ERR_ERL_UNEXPECTED_X_FORWARDED_FOR** — `N8N_SECURITY_TRUST_PROXY=true`  

---

## 🔧 Полезные команды

```
sudo docker-compose logs
sudo docker-compose logs n8n
sudo docker-compose restart
sudo docker-compose pull && sudo docker-compose up -d
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
```

---

## 🛠️ 11. Добавление утилит для работы с субтитрами и аудио

1. В том же каталоге уже есть `Dockerfile` и `docker-compose.yml`.  
2. Соберите и запустите образ, чтобы в контейнере появились `yt-dlp`, `ffmpeg` и `sed`:  
   ```
   cd /opt/n8n
   sudo docker-compose build n8n
   sudo docker-compose up -d n8n
   ```
3. Проверьте доступность утилит:  
   ```
   sudo docker-compose exec n8n sh -c "which yt-dlp && which ffmpeg && which sed"
   ```

---

## 🛠️ 12. Тест субтитров и аудио в n8n

1. Добавьте узел **Execute Command** с таким кодом:
   ```
   yt-dlp --skip-download --write-auto-subs --write-sub \
     --sub-lang en --sub-format srt \
     -o "/tmp/sub_{{ $json.id }}" "{{ $json.url }}" \
   && subs=$(ls /tmp/sub_{{ $json.id }}.*.srt | head -n1) \
   && sed -E '/^[0-9]+$/d; /-->/d; /^$/d' "$subs" > "/tmp/sub_{{ $json.id }}.txt"
   ```
2. Запустите его на примере `https://www.youtube.com/watch?v=MTm_Xytwz6g`.  
3. Убедитесь, что файл `/tmp/sub_<id>.txt` создан и содержит текст.

---

## 🔢 Итоговая нумерация шагов

1. Регистрация домена  
2. Резерв статического IP  
3. Настройка DNS A-записи  
4. Правила firewall в GCP  
5. UFW на VM  
6. Остановка системного nginx  
7. Установка Docker & Compose  
8. Создание `Dockerfile` и `docker-compose.yml`  
9. Запуск контейнеров  
10. Проверка доступности сервисов  
11. Добавление `yt-dlp`, `ffmpeg`, `sed` в контейнер  
12. Тест субтитров и аудио  

После выполнения всех пунктов n8n будет доступен по HTTPS, с автоматическим SSL и встроенными утилитами для работы с медиа.
