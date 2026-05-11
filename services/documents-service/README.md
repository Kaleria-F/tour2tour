# Documents Service

Сервис документов отвечает за загрузку, хранение и выдачу файлов поездки (PDF/PNG/JPEG).
Работает в микросервисной схеме через API Gateway (`/documents/*`).

## Реализованный функционал

- загрузка документов, привязанных к конкретной поездке (`trip_id`);
- хранение метаданных в PostgreSQL (`documents-db`):
  - `user_id`, `trip_id`, `object_key`, `file_name`, `content_type`, `size_bytes`, `created_at`;
- получение списка документов поездки;
- открытие документов из приложения через presigned download URL;
- поддержка форматов `application/pdf`, `image/png`, `image/jpeg`;
- удаление документа (из S3 и из БД);
- валидация размера и сигнатуры файла (magic bytes);
- единый контур авторизации по JWT (`Authorization: Bearer <token>`);
- синхронизация между устройствами через сервер (метаданные + общий объектный сторедж).

## API (через Gateway)

Базовый URL локально: `http://127.0.0.1:8888`

- `POST /documents/storage/ensure-bucket` - создать/проверить bucket и CORS
- `POST /documents/upload-direct` - прямой upload через multipart
- `POST /documents/upload-init` + `POST /documents/upload-complete` - двухшаговый upload через presigned PUT
- `GET /documents/trips/{trip_id}` - список документов поездки
- `POST /documents/download-url` - получить ссылку на открытие/просмотр
- `DELETE /documents/object?object_key=...` - удалить документ

## Переменные окружения

Для локального прогона значения задаются в корневом `.env`.

Обязательные для `documents-service`:

- `S3_ENDPOINT`
- `S3_PUBLIC_ENDPOINT`
- `S3_REGION`
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `S3_BUCKET`
- `S3_USE_SSL`
- `S3_VERIFY_SSL`
- `S3_FORCE_PATH_STYLE`
- `S3_PRESIGN_TTL_SECONDS`
- `S3_SSE_MODE`
- `S3_CORS_ALLOWED_ORIGINS`
- `MAX_UPLOAD_SIZE_BYTES`
- `ENABLE_UPLOAD_SCAN`

## Локальный запуск (Docker Compose + Gateway)

Из корня репозитория:

```powershell
docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

Проверка контейнеров:

```powershell
docker compose --env-file .env -f infra/docker-compose.yml ps
```

Проверка gateway:

```powershell
curl http://127.0.0.1:8888/health
```

## Быстрая проверка сценария документов

1. Получить JWT через `auth-service` (`/auth/login`).
2. Вызвать `POST /documents/storage/ensure-bucket`.
3. Загрузить файл через `POST /documents/upload-direct`.
4. Проверить список `GET /documents/trips/{trip_id}`.
5. Получить ссылку `POST /documents/download-url` и открыть документ.
6. Удалить `DELETE /documents/object`.

## Примечания по безопасности

- Для `download-url` и `delete` сервис дополнительно проверяет, что документ есть в БД и принадлежит текущему пользователю.
- Не храните production-ключи в репозитории, используйте секреты CI/CD или менеджер секретов.
