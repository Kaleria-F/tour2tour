# как запускать (local + production)

Этот файл объясняет, как запускать проект в двух режимах:

локальная разработка (для тестирования и исправлений)

продакшн на домене (24tour2tour.ru)

Все команды выполняются из корня репозитория:
C:\Users\Valeria\tour2tour

---

## 1) Локальная разработка

### 1.1 Запуск backend локально (микросервисы + gateway)
Запускает локальные PostgreSQL, Redis, все сервисы и локальный Nginx‑gateway.

Из корня репозитория::
```bash
docker compose -f infra/docker-compose.yml up --build -d
```

проверка:
```bash
curl http://127.0.0.1:8000/health
```

локальные порты
- gateway: `http://127.0.0.1:8000`
- auth-service: `http://127.0.0.1:8001`
- trips-service: `http://127.0.0.1:8002`
- recommendations-service: `http://127.0.0.1:8003`
- payments-service: `http://127.0.0.1:8004`

### Запуск миграций локально (при необходимости)
```bash
docker compose -f infra/docker-compose.yml exec auth-service alembic upgrade head
docker compose -f infra/docker-compose.yml exec trips-service alembic upgrade head
```

### Запуск Flutter-приложения локально
Конфигурация поддерживает переопределение API  через
`--dart-define=API_BASE_URL=...`.

Web (локальный gateway 127.0.0.1:8000)
```bash
cd frontend/tour2tour_app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android emulator (local gateway):
```bash
cd frontend/tour2tour_app
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Реальное устройство (использовать IP ПК в локальной сети)
```bash
cd frontend/tour2tour_app
flutter run -d <device_id> --dart-define=API_BASE_URL=http://<LAN_IP>:8000
```

---

## 2) 2) Продакшн (домен)

### 2.1 Деплой backend на VPS

На сервере:
```bash
cd ~/tour2tour
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod up --build -d
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod exec auth-service alembic upgrade head
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod exec trips-service alembic upgrade head
```

### 2.2 API base URL (production)
`https://api.24tour2tour.ru`

### 2.3 Сборка и деплой Flutter Web (продакшн)
Локальная сборка:
```bash
cd frontend/tour2tour_app
flutter build web --release --dart-define=API_BASE_URL=https://api.24tour2tour.ru
```

Загрузка на сервер:
```bash
scp -i C:\Users\Valeria\tour2tour\key.txt -r frontend/tour2tour_app/build/web root@89.23.97.65:/var/www/tour2tour
```
После загрузки Nginx отдаёт сайт из папки /var/www/tour2tour.

---

## 3) Процесс обновления (продакшн)

1. git pull на сервере
2. docker compose ... up --build -d
3. запустить миграции (если были изменения)
4. обновить сборку Flutter Web, если изменялся фронтенд


