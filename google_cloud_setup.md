# Полная инструкция: Развёртывание n8n на Ubuntu VM в Google Cloud с привязкой домена и HTTPS

## 1. Создание виртуальной машины (VM) в Google Cloud

1. Откройте Google Cloud Console и перейдите в **Compute Engine → VM instances**.  
2. Нажмите **Create Instance**.  
3. Задайте имя, например `n8n-server`.  
4. В разделе **Region & Zone** выберите зону `europe-north2-b`.  
5. В блоке **Machine configuration**:
   - Machine family: **General-purpose**  
   - Series: **E2**  
   - Machine type: e2-medium (2 vCPU, 4 GB RAM)  
6. В блоке **Boot disk** нажмите **Change**, выберите:
   - OS: **Ubuntu**  
   - Version: **Ubuntu 22.04 LTS**  
   - Size: 20 GB (SSD)  
   - Нажмите **Select**.  
7. В разделе **Firewall** отметьте галочки:
   - **Allow HTTP traffic**  
   - **Allow HTTPS traffic**  
8. Нажмите **Create** и дождитесь готовности VM.

## 2. Назначение статического внешнего IP

1. Перейдите **VPC Network → External IP addresses**.  
2. Найдите строку с вашей VM `n8n-server` и столбец **Type** нажмите **Static → Reserve static address**.  
3. Присвойте имя, например `n8n-ip`, и подтвердите.  
4. Теперь внешний IP закреплён и не изменится.

## 3. Настройка Google Cloud DNS (публичная зона)

1. Перейдите в **Cloud DNS → Zones**.  
2. Нажмите **Create zone**.  
3. Заполните:
   - Zone name: `grouchily`  
   - DNS name: `grouchily.ru.` (обязательно с точкой в конце)  
   - Description: `DNS for n8n`  
   - Type: **Public**  
4. Нажмите **Create**.  
5. Сохраните четыре NS-записи, которые появятся (ns-cloud-…).

## 4. Привязка домена у регистратора

1. В панели вашего регистратора домена (например, NIC.ru) откройте управление DNS для `grouchily.ru`.  
2. Замените NS-серверы на полученные в Google Cloud (ns-cloud-e1… ns-cloud-e4…).  
3. Сохраните. После этого включится управление записями в Google Cloud DNS.

## 5. Создание записей A в Google Cloud DNS

1. Вернитесь в **Cloud DNS → Zones → grouchily**.  
2. Нажмите **Add record set**.  
3. Для корня домена:
   - DNS Name: оставьте пустым или `@`.  
   - Resource Record Type: **A**  
   - IPv4 Address: ваш статический IP (`34.51.230.104`)  
   - TTL: оставьте default.  
   - Нажмите **Create**.  
4. Для поддомена `n8n` (опционально):
   - DNS Name: `n8n`  
   - Type: **A**  
   - Address: тот же IP.  
   - Нажмите **Create**.

## 6. Проверка DNS

```bash
nslookup grouchily.ru
nslookup n8n.grouchily.ru
ping -c1 grouchily.ru
```

IP должен соответствовать `34.51.230.104`.

## 7. Установка n8n на VM

1. Подключитесь к VM через SSH в браузере (Compute Engine → SSH).  
2. Выполните следующие команды:

```bash
# Обновление и установка зависимостей
sudo apt update -qq
sudo apt install -y docker.io docker-compose curl openssl

# Создание папок
sudo mkdir -p /opt/n8n/{postgres,data,certs}
sudo chown $USER:$USER /opt/n8n -R
cd /opt/n8n

# Скачивание скрипта установки
curl -fsSL https://raw.githubusercontent.com/daoqub/n8n/main/install-n8n.sh -o install-n8n.sh
chmod +x install-n8n.sh

# Запуск установки
sudo ./install-n8n.sh
```

3. При запросе:
   - **Email**: ваш e-mail (для Let’s Encrypt + уведомлений).  
   - **Пароль PostgreSQL**: надёжный, минимум 8 символов.  
   - **Режим SSL**: введите `1` (Let’s Encrypt).  
   - **Домен**: `grouchily.ru` (или `n8n.grouchily.ru`, если настроили поддомен).  

4. Скрипт сгенерирует `docker-compose.yml`, установит и запустит сервисы:
   - PostgreSQL  
   - nginx-proxy + acme-companion  
   - n8n  

5. По завершении в выводе и в файле `/opt/n8n/PASSWORDS.txt` будут:
   - Адрес доступа (`https://grouchily.ru` или `https://n8n.grouchily.ru`)  
   - Email и пароль БД

## 8. Окончательная проверка

- Откройте браузер по адресу `https://grouchily.ru`.  
- Дождитесь выдачи сертификата Let’s Encrypt (может занять до минуты).  
- При успешном выводе n8n-интерфейса установка завершена.

***

Теперь n8n работает на Google Cloud VM, привязан к вашему публичному домену с автоматическим HTTPS через Let’s Encrypt.
