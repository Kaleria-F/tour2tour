# MinIO + S3 Setup (MVP)

Этот гайд показывает, как поднять хранилище документов локально через MinIO и как переключиться на S3 в production.

## 1) Что уже добавлено в код

- `infra/docker-compose.yml`:
  - добавлен `minio` (`:9000` API, `:9001` Console),
  - добавлен `documents-service` (`:8005`),
  - `documents-service` зависит от `minio`.
- `infra/nginx/local.conf`:
  - добавлен роутинг `/documents/*` -> `documents-service`.
- `infra/docker-compose.prod.yml`:
  - добавлен `documents-service` с S3-настройками через env.
- Новый сервис `services/documents-service`:
  - JWT-проверка пользователя,
  - `POST /documents/storage/ensure-bucket`,
  - `POST /documents/upload-init` (presigned PUT),
  - `POST /documents/download-url` (presigned GET).

## 2) Локальный запуск MinIO + документов

Запускать из корня проекта:

```powershell
cd C:\Users\Yulia\tour2tour
docker compose -f infra/docker-compose.yml up -d --build
```

Проверка:

```powershell
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8005/health
```

MinIO Console:
- URL: `http://127.0.0.1:9001`
- login: `minioadmin`
- password: `minioadmin`

## 3) Создание bucket

Нужен JWT пользователя (`Authorization: Bearer <token>`):

```powershell
curl -X POST http://127.0.0.1:8000/documents/storage/ensure-bucket -H "Authorization: Bearer <token>"
```

Bucket по умолчанию: `tour2tour-documents`.

## 4) Загрузка файла (через presigned URL)

1. Получить upload URL:

```powershell
curl -X POST http://127.0.0.1:8000/documents/upload-init ^
  -H "Authorization: Bearer <token>" ^
  -H "Content-Type: application/json" ^
  -d "{\"trip_id\":1,\"file_name\":\"ticket.pdf\",\"content_type\":\"application/pdf\"}"
```

2. В ответе взять `upload_url` и выполнить `PUT` файла напрямую в MinIO/S3.

## 5) Скачивание файла

Получить download URL:

```powershell
curl -X POST http://127.0.0.1:8000/documents/download-url ^
  -H "Authorization: Bearer <token>" ^
  -H "Content-Type: application/json" ^
  -d "{\"object_key\":\"users/1/trips/1/<uuid>-ticket.pdf\"}"
```

## 6) Production (S3)

В `infra/.env.prod` должны быть:

```env
S3_ENDPOINT=https://storage.yandexcloud.net
S3_REGION=ru-central1
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_BUCKET=tour2tour-documents
S3_USE_SSL=true
S3_FORCE_PATH_STYLE=false
```

После этого:

```bash
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod up --build -d
```

## 7) Базовая безопасность (что уже есть)

- Bucket не публичный.
- Только short-lived presigned URL (5 минут).
- Проверка JWT.
- Ограничение на типы файлов (`pdf`, `jpg`, `png`).
- Пользователь может получить download URL только для своего namespace `users/{user_id}/...`.

## 8) Что нужно добавить следующим шагом для полноценного MVP документов

- PostgreSQL для `documents-service`.
- Таблица метаданных документов (`trip_id`, owner, size, status).
- Проверка владения `trip_id` через `trips-service`.
- Удаление документа и список документов по trip.
