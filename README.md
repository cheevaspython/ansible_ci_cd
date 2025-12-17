# Calorie Product - Ansible Deployment

Production-ready Ansible deployment для микросервиса calorie_product на Docker Swarm.

## Ключевые возможности

✅ Автоматизированный deployment через GitLab CI/CD  
✅ Zero-downtime обновления  
✅ Управление миграциями базы данных  
✅ Rollback на предыдущую версию  
✅ Template-based конфигурация  
✅ Переиспользуемая архитектура для всех микросервисов

## Быстрый старт

### 1. Установка зависимостей

```bash
pip install ansible
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 2. Настройка inventory

Отредактируйте файлы с IP адресами серверов:

```bash
vim inventories/test/hosts
vim inventories/production/hosts
```

### 3. Проверка окружения

```bash
cd scripts
chmod +x setup_environment.sh
./setup_environment.sh test
```

### 4. Создание Docker secrets

**ВАЖНО:** Secrets создаются **ВРУЧНУЮ** на Swarm manager ноде один раз!

```bash
# На Swarm manager ноде выполните:
echo -n "your_postgres_user" | docker secret create postgres_user -
echo -n "your_secure_password" | docker secret create postgres_password_product -
echo -n "your_redis_password" | docker secret create redis_product_password -
echo -n "your_s3_access_key" | docker secret create s3_access_key -
echo -n "your_s3_secret_key" | docker secret create s3_secret_key -

# Проверьте созданные secrets:
docker secret ls
```

**⚠️ БЕЗОПАСНОСТЬ:**
- НЕ храните пароли в скриптах или Git
- Сохраните пароли в безопасном месте (KeePass, 1Password)
- После создания secrets НЕ МОГУТ быть прочитаны из Docker

### 5. Деплой

```bash
cd ../ansible
ansible-playbook deploy.yml -i inventories/test
ansible-playbook migrate.yml -i inventories/test
```

## Структура проекта

```
.
├── ansible/
│   ├── deploy.yml              # Основной playbook деплоя
│   ├── migrate.yml             # Миграции БД
│   ├── rollback.yml            # Откат
│   ├── status.yml              # Проверка статуса
│   ├── ansible.cfg             # Конфигурация Ansible
│   ├── requirements.yml        # Ansible коллекции
│   ├── inventories/
│   │   ├── test/
│   │   │   ├── hosts           # Test серверы
│   │   │   └── group_vars/
│   │   │       └── all.yml     # Test переменные
│   │   └── production/
│   │       ├── hosts           # Production серверы
│   │       └── group_vars/
│   │           └── all.yml     # Production переменные
│   └── templates/
│       └── docker-stack.yml.j2 # Шаблон stack файла
├── scripts/
│   └── setup_environment.sh    # Проверка окружения
├── .gitlab-ci.yml              # CI/CD pipeline
└── MANUAL.txt                  # Подробная документация
```

## Основные команды

### Deployment

```bash
ansible-playbook deploy.yml -i inventories/production
```

### Миграции

```bash
ansible-playbook migrate.yml -i inventories/production
```

### Rollback

```bash
ansible-playbook rollback.yml -i inventories/production
```

### Проверка статуса

```bash
ansible-playbook status.yml -i inventories/production
```

### Dry run (без изменений)

```bash
ansible-playbook deploy.yml -i inventories/test --check
```

## GitLab CI/CD

Pipeline stages:

1. **build** - Собирает Docker image
2. **test** - Запускает тесты
3. **deploy** - Деплоит на Docker Swarm (manual)
4. **migrate** - Запускает миграции БД (manual)
5. **rollback** - Откатывает deployment (manual)

Настройте в GitLab CI/CD Variables:

- `DEPLOY_TOKEN_USERNAME`
- `DEPLOY_TOKEN_PASSWORD`
- `SSH_PRIVATE_KEY`
- `TEST_SERVER_HOST`
- `PROD_SERVER_HOST`

## Адаптация для других микросервисов

Для использования с другим микросервисом (например, calorie_auth):

1. Обновите `inventories/*/group_vars/all.yml`:

```yaml
service_name: "auth" # было: "product"
service_suffix: "_auth"
registry_image: "registry.gitlab.com/cheepython/calorie_auth"
```

2. Обновите `.gitlab-ci.yml`:

```yaml
SERVICE_NAME: "auth"
SERVICE_SUFFIX: "_auth"
CI_REGISTRY_IMAGE: "registry.gitlab.com/cheepython/calorie_auth"
```

3. Создайте соответствующие Docker secrets:

```bash
echo -n "password" | docker secret create postgres_password_auth -
echo -n "password" | docker secret create redis_auth_password -
```

4. Задеплойте:

```bash
ansible-playbook deploy.yml -i inventories/test
```

## Требования

- Python 3.8+
- Ansible 2.14+
- Docker Swarm cluster
- GitLab CI/CD (опционально)

## Безопасность

✓ SSH ключи ED25519  
✓ Docker Secrets для паролей  
✓ Deploy токены (не personal tokens)  
✓ Protected CI/CD переменные  
✓ Non-root контейнеры  
✓ Internal networks

## Troubleshooting

### Проблема: "Cannot connect to Docker daemon"

```bash
ssh admin_remote@SERVER "systemctl status docker"
```

### Проблема: "Secret not found"

```bash
echo 'password' | docker secret create secret_name -
```

### Проблема: "Image pull failed"

Проверьте deploy token и registry authentication.

### Проблема: "Migration timeout"

Увеличьте timeout:

```bash
ansible-playbook migrate.yml -i inventories/production -e migration_timeout=300
```

## Документация

Полная документация: **MANUAL.txt**

Содержит:

- Детальные инструкции по настройке
- Все возможные сценарии использования
- Troubleshooting guide
- Security best practices
- Примеры адаптации для других сервисов

## Поддержка

- Issues: GitLab Issues
- Documentation: MANUAL.txt
- Logs: `docker service logs <service>`
- Status: `ansible-playbook status.yml`

---

**Version**: 1.0  
**Updated**: December 2025  
**Service**: calorie_product (reusable for all microservices)
