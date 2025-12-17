# 🚀 БЫСТРЫЙ СТАРТ - Ansible CI/CD для Calorie Product

## 📋 Информация о окружениях

### Теги Docker образов:
- **`:tr`** - Test (branch `develop`)
- **`:pr`** - Production (branch `prod`)

### Test окружение:
- **Manager Node IP:** `103.88.243.109`
- **User:** `admin_remote`
- **SSH Port:** `3322`

---

## ⚙️ ПРЕДВАРИТЕЛЬНАЯ НАСТРОЙКА (ОДИН РАЗ)

### 1️⃣ На вашей машине (где будет GitLab Runner с Ansible)

```bash
# Установка Ansible
pip install ansible

# Клонирование репозитория
git clone <repository_url>
cd ansible_ci_cd

# Установка Ansible коллекций
cd ansible
ansible-galaxy collection install -r requirements.yml

# Генерация SSH ключа для Ansible
ssh-keygen -t ed25519 -f ~/.ssh/ansible_swarm -C "ansible-deploy"
```

### 2️⃣ На Test Swarm Manager (103.88.243.109)

```bash
# Подключитесь к серверу
ssh admin_remote@103.88.243.109 -p 3322

# Добавьте публичный ключ Ansible
# (скопируйте содержимое ~/.ssh/ansible_swarm.pub с вашей машины)
mkdir -p ~/.ssh
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Создайте Docker secrets (ВАЖНО!)
echo -n "postgres" | docker secret create postgres_user -
echo -n "your_secure_password_here" | docker secret create postgres_password_product -
echo -n "your_redis_password_here" | docker secret create redis_product_password -
echo -n "your_s3_access_key" | docker secret create s3_access_key -
echo -n "your_s3_secret_key" | docker secret create s3_secret_key -

# Проверьте созданные secrets
docker secret ls

# Проверьте Docker Swarm
docker node ls
docker info | grep Swarm
```

### 3️⃣ Настройка GitLab CI/CD Variables

В **GitLab Project → Settings → CI/CD → Variables** добавьте:

| Variable | Type | Value | Masked | Protected |
|----------|------|-------|--------|-----------|
| `SSH_PRIVATE_KEY` | File | Содержимое `~/.ssh/ansible_swarm` | ✅ | ✅ |
| `DEPLOY_TOKEN_USERNAME` | Variable | `deploy-token` | ❌ | ✅ |
| `DEPLOY_TOKEN_PASSWORD` | Variable | Ваш GitLab Deploy Token | ✅ | ✅ |
| `TEST_SERVER_HOST` | Variable | `103.88.243.109` | ❌ | ❌ |
| `PROD_SERVER_HOST` | Variable | `YOUR_PROD_IP` | ❌ | ✅ |

---

## 🧪 ТЕСТИРОВАНИЕ ЛОКАЛЬНО (перед CI/CD)

### Проверка подключения

```bash
# Из корня проекта
cd ansible

# Проверка SSH connectivity
ansible swarm_managers -i inventories/test/hosts.yml -m ping

# Проверка Docker Swarm
ansible swarm_managers -i inventories/test/hosts.yml -m shell -a "docker node ls"

# Проверка secrets
ansible swarm_managers -i inventories/test/hosts.yml -m shell -a "docker secret ls"
```

### Проверка окружения (автоматический скрипт)

```bash
# Из корня проекта
./scripts/setup_environment.sh test
```

Должны быть:
- ✅ Ansible installed
- ✅ Collections installed
- ✅ Inventory file exists
- ✅ SSH connectivity OK
- ✅ Docker Swarm is active
- ✅ All required Docker secrets present

### Тестовый деплой (dry-run)

```bash
cd ansible

# Проверка синтаксиса
ansible-playbook deploy.yml -i inventories/test/hosts.yml --syntax-check

# Dry-run (без изменений)
ansible-playbook deploy.yml -i inventories/test/hosts.yml --check

# Если dry-run прошел успешно - реальный деплой
ansible-playbook deploy.yml -i inventories/test/hosts.yml
```

При первом запросе введите GitLab Registry пароль (Deploy Token).

### Проверка деплоя

```bash
# На Swarm manager
ssh admin_remote@103.88.243.109 -p 3322

# Проверка стека
docker stack ls
docker stack services main

# Проверка конкретных сервисов
docker service ls --filter name=main_
docker service ps main_backend_product

# Логи
docker service logs main_backend_product --tail 50 --follow
```

---

## 🔄 ИСПОЛЬЗОВАНИЕ ЧЕРЕЗ GitLab CI/CD

### Workflow:

```
develop (test) → build → test → deploy:test (manual) → migrate:test (manual)
prod           → build → deploy:production (manual) → migrate:production (manual)
```

### Деплой на TEST:

1. Пушим в ветку `develop`
2. Pipeline автоматически:
   - ✅ Собирает образ с тегом `:tr`
   - ✅ Запускает тесты
3. **Вручную** жмем **"deploy:test"** в GitLab Pipeline
4. **Вручную** жмем **"migrate:test"** для миграций БД

### Деплой на PRODUCTION:

1. Пушим в ветку `prod`
2. Pipeline автоматически:
   - ✅ Собирает образ с тегом `:pr`
3. **Вручную** жмем **"deploy:production"**
4. **Вручную** жмем **"migrate:production"**

### Откат (Rollback):

Если что-то пошло не так:

```bash
# Локально через Ansible
cd ansible
ansible-playbook rollback.yml -i inventories/test/hosts.yml -e "confirm_rollback=yes"

# Или через GitLab Pipeline
# Жмем "rollback:production" (manual)
```

---

## 🔍 МОНИТОРИНГ И ПРОВЕРКА

### Проверка статуса через Ansible

```bash
cd ansible
ansible-playbook status.yml -i inventories/test/hosts.yml
```

Покажет:
- Swarm nodes
- Stack services
- Текущий deployed image
- Replicas status

### Проверка на сервере

```bash
ssh admin_remote@103.88.243.109 -p 3322

# Список всех сервисов
docker service ls --filter name=main_

# Детальная информация
docker service ps main_backend_product --no-trunc

# Логи
docker service logs main_backend_product --tail 100 -f

# Проверка образа
docker service inspect main_backend_product --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'

# Healthcheck
curl http://localhost:8088/api/v1/healthcheck/
```

---

## 📦 АДАПТАЦИЯ ДЛЯ ДРУГИХ СЕРВИСОВ (например, calorie_auth)

### 1. Обновить переменные:

```bash
# inventories/*/group_vars/all.yml
service_name: "auth"          # было: "product"
service_suffix: "_auth"       # было: "_product"
registry_image: "registry.gitlab.com/cheepython/calorie_auth"

# .gitlab-ci.yml
SERVICE_NAME: "auth"
SERVICE_SUFFIX: "_auth"
CI_REGISTRY_IMAGE: "registry.gitlab.com/cheepython/calorie_auth"
```

### 2. Создать новые secrets на Swarm:

```bash
ssh admin_remote@103.88.243.109 -p 3322

echo -n "password" | docker secret create postgres_password_auth -
echo -n "password" | docker secret create redis_auth_password -
docker secret ls
```

### 3. Деплой:

```bash
cd ansible
ansible-playbook deploy.yml -i inventories/test/hosts.yml
```

---

## 🐛 TROUBLESHOOTING

### Проблема: SSH connectivity failed

```bash
# Проверка ключа
ssh -i ~/.ssh/ansible_swarm admin_remote@103.88.243.109 -p 3322

# Проверка Ansible
ansible swarm_managers -i inventories/test/hosts.yml -m ping -vvv
```

### Проблема: Secret not found

```bash
# На manager node
docker secret ls
docker secret inspect postgres_password_product
```

### Проблема: Service не запускается

```bash
# Логи задачи
docker service ps main_backend_product --no-trunc

# Детальные логи
docker service logs main_backend_product --tail 100
```

### Проблема: Migration timeout

```bash
cd ansible
ansible-playbook migrate.yml -i inventories/test/hosts.yml -e migration_timeout=300
```

---

## 📚 ПОЛЕЗНЫЕ КОМАНДЫ

### Docker Swarm

```bash
# Состояние кластера
docker node ls
docker stack ls

# Скейлинг
docker service scale main_backend_product=3

# Обновление образа
docker service update --image registry.gitlab.com/cheepython/calorie_product:tr main_backend_product
```

### Ansible

```bash
# Verbose режим
ansible-playbook deploy.yml -i inventories/test/hosts.yml -vvv

# Specific tags
ansible-playbook deploy.yml -i inventories/test/hosts.yml --tags deploy,verify

# Limit to specific host
ansible-playbook deploy.yml -i inventories/test/hosts.yml --limit test-swarm-01
```

---

## ✅ ЧЕКЛИСТ ПЕРЕД ПЕРВЫМ ЗАПУСКОМ

- [ ] SSH ключи созданы и добавлены на Swarm manager
- [ ] Docker secrets созданы на Swarm manager
- [ ] GitLab CI/CD Variables настроены
- [ ] `setup_environment.sh test` проходит успешно
- [ ] Ansible может подключиться к manager node
- [ ] Docker Swarm active на manager node
- [ ] Сети созданы: `internal_network`, `public_network`, `main_internal_network`
- [ ] GitLab Runner настроен (docker + shell)

---

## 🆘 SUPPORT

- **Документация:** `MANUAL.txt` (полная версия)
- **Примеры команд:** `EXAMPLES.txt`
- **README:** `README.md`
- **Issues:** GitLab Issues

---

**Версия:** 1.0
**Дата:** December 2025
**Проект:** calorie_product (универсальный для всех микросервисов)
