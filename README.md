# Tour2Tour

Основные режимы работы проекта:
- локальная разработка и тестирование;
- production-развертывание на VPS с доменом `24tour2tour.ru`.

Все локальные команды ниже выполняются из корня репозитория:
`C:\Users\Valeria\tour2tour`

## Локальный запуск

### 1. Поднять backend и инфраструктуру
```bash
docker compose -f infra/docker-compose.yml up --build -d
```

### 2. Выполнить миграции
```bash
docker compose -f infra/docker-compose.yml exec auth-service alembic upgrade head
docker compose -f infra/docker-compose.yml exec trips-service alembic upgrade head
```

### 3. Проверить gateway
```bash
curl.exe http://127.0.0.1:8888/health
```

Ожидаемый ответ:
```json
{"status":"ok"}
```

### 4. Запустить Flutter Web локально
```bash
cd frontend/tour2tour_app
flutter pub get
flutter run -d chrome
```

Локальный web использует:
- `http://127.0.0.1:8888`

### 5. Запустить Flutter Android Emulator локально
```bash
cd frontend/tour2tour_app
flutter pub get
flutter run -d emulator-5554
```

Android emulator использует:
- `http://10.0.2.2:8888`

### 6. Запустить фронт против production API
```bash
cd frontend/tour2tour_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://api.24tour2tour.ru
```

## Команды для тестирования

### Проверить список контейнеров
```bash
docker compose -f infra/docker-compose.yml ps
```

### Проверить логи gateway
```bash
docker compose -f infra/docker-compose.yml logs gateway
```

### Проверить логи auth-service
```bash
docker compose -f infra/docker-compose.yml logs auth-service
```

### Проверить локальный auth endpoint
```bash
curl.exe -i http://127.0.0.1:8888/auth/register
```

Ожидаемо для GET:
- `405 Method Not Allowed`

Это означает, что маршрутизация до auth-service работает.

## Очистка и перезапуск

### Остановить локальный контур
```bash
docker compose -f infra/docker-compose.yml down
```

### Остановить и удалить тома
```bash
docker compose -f infra/docker-compose.yml down -v
```

Используй это только если нужно полностью сбросить локальные БД.

### Пересобрать сервисы заново
```bash
docker compose -f infra/docker-compose.yml up --build -d
```

### Пересоздать только gateway
```bash
docker compose -f infra/docker-compose.yml up -d --force-recreate gateway
```

## Production

### Backend на VPS
```bash
cd ~/tour2tour
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod up --build -d
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod exec auth-service alembic upgrade head
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod exec trips-service alembic upgrade head
```

### Flutter Web build для production
```bash
cd frontend/tour2tour_app
flutter build web --release --dart-define=API_BASE_URL=https://api.24tour2tour.ru
```

## Ветки

- `main` — стабильная production-ветка
- `develop` — разработка и локальное тестирование

Поток работы:
1. разработка идет в `develop`;
2. после проверки создается PR из `develop` в `main`;
3. деплой запускается из `main`.

## Auto-deploy

Workflow:
- `.github/workflows/deploy.yml`

Secrets GitHub Actions:
- `SSH_HOST`
- `SSH_USER`
- `SSH_KEY`
- `SSH_PORT`

Текущий workflow делает:
- `git pull` на сервере;
- `docker compose ... up --build -d`;
- `alembic upgrade head` для `auth-service` и `trips-service`.
