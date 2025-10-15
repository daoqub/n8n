# N8N Auto-Install Script

Автоматическая установка N8N с Docker, PostgreSQL и гибкой поддержкой SSL (Let’s Encrypt, самоподписанный или без SSL — по IP).

***

## Содержание

- [Быстрая установка](#быстрая-установка)  
- [Режимы работы](#режимы-работы)  
- [Доступ к N8N](#доступ-к-n8n)  
- [Управление и обновление](#управление-и-обновление)  
- [Подключение домена с SSL](#подключение-домена-с-ssl)  
- [Пример установки из репозитория](#пример-установки-из-репозитория)  

***

## Быстрая установка

Скачайте и запустите скрипт в один этап:

```bash
# Через curl
curl -fsSL https://raw.githubusercontent.com/daoqub/n8n/main/install-n8n.sh | sudo bash
```
```bash
# Или через wget
wget -qO- https://raw.githubusercontent.com/daoqub/n8n/main/install-n8n.sh | sudo bash
```

Скрипт автоматически:
1. Устанавливает Docker и Docker Compose  
2. Спрашивает режим SSL (Let’s Encrypt, самоподписанный, без SSL)  
3. Разворачивает PostgreSQL и N8N  
4. Настраивает nginx-proxy и получает SSL-сертификаты (при выборе соответствующего режима)  
5. Сохраняет учётные данные в `/opt/n8n/PASSWORDS.txt`  

***

## Режимы работы

При запуске скрипт предложит три варианта:

1) **Let’s Encrypt**  
   - Автоматическое получение и обновление бесплатных сертификатов  
   - Требуется домен и корректные DNS-записи  

2) **Самоподписанный сертификат (10 лет)**  
   - Работает без настройки DNS  
   - Браузер будет выдавать предупреждение о безопасности  

3) **Без SSL (доступ по IP:5678)**  
   - Быстрый старт по внешнему IP  
   - HTTP без шифрования  

***

## Доступ к N8N

- **По IP без SSL** (режим 3):  
  ```
  http://<EXTERNAL_IP_VM>:5678
  ```

- **С самоподписанным SSL** (режим 2):  
  ```
  https://<EXTERNAL_IP_VM>:5678
  ```

- **С Let’s Encrypt** (режим 1, после DNS):  
  ```
  https://<YOUR_DOMAIN>
  ```

***

## Управление и обновление

1. Перейдите в директорию установки:
   ```bash
   cd /opt/n8n
   ```
2. **Статус контейнеров**:
   ```bash
   docker-compose ps
   ```
3. **Просмотр логов**:
   ```bash
   docker-compose logs -f n8n
   ```
4. **Перезапуск сервисов**:
   ```bash
   docker-compose restart
   ```
5. **Остановка**:
   ```bash
   docker-compose down
   ```
6. **Обновление N8N**:
   ```bash
   docker-compose pull n8n
   docker-compose up -d n8n
   ```

***

## Подключение домена с SSL

1. В панели вашего DNS-провайдера или Google Cloud DNS создайте A-запись:
   ```
   YOUR_DOMAIN → EXTERNAL_IP_VM
   ```
2. Получите NS-записи вашей DNS-зоны (Google Cloud DNS или другой провайдер). Для Google Cloud DNS они выглядят примерно так:
   ```
   ns-cloud-a1.googledomains.com.
   ns-cloud-a2.googledomains.com.
   ns-cloud-a3.googledomains.com.
   ns-cloud-a4.googledomains.com.
   ```
3. В панели регистратора домена замените текущие NS-записи на эти четыре.
4. Подождите 10–60 минут для распространения DNS.

После этого при выборе режима Let’s Encrypt скрипт автоматически получит сертификат и включит HTTPS.

***

## Пример установки из репозитория

```bash
# Клонирование репозитория
git clone https://github.com/daoqub/n8n.git
cd n8n

# Запуск скрипта
chmod +x install-n8n.sh
sudo bash install-n8n.sh
```

Или в одну команду:

```bash
curl -fsSL https://raw.githubusercontent.com/daoqub/n8n/main/install-n8n.sh | sudo bash
```

***

Готово! После выполнения инструкции у вас будет полноценный N8N, доступный и по IP, и по домену с SSL.

```bash
##Установка 3x-ui
wget -qO- https://raw.githubusercontent.com/Oreomeow/3x-ui/master/install/install.sh | bash
```
