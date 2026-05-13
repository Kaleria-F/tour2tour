# Documents Service

Новая реализация сервиса документов с чистой серверной логикой (без браузерного S3 PUT).

## Что реализовано

- загрузка документов к конкретной поездке (`trip_id`);
- хранение метаданных в PostgreSQL (`documents-db`);
- список документов поездки;
- открытие документа из приложения через backend-прокси `/documents/content`;
- поддержка PDF/PNG/JPEG;
- удаление документа (S3 + БД);
- уведомления об ошибках/успехах через HTTP-коды и `detail`;
- синхронизация между устройствами через серверный контур.

## API (через gateway)

- `POST /documents/upload-direct` - multipart загрузка файла
- `GET /documents/trips/{trip_id}` - список файлов поездки
- `POST /documents/download-url` - получить ссылку на просмотр через backend
- `GET /documents/content?object_key=...` - чтение файла через backend
- `DELETE /documents/object?object_key=...` - удалить файл

## Локальный запуск

```powershell
docker compose --env-file .env -f infra/docker-compose.yml up -d --build --force-recreate documents-service gateway
```

## Проверка

1. Загрузить документ (`upload-direct`)
2. Открыть документ (`download-url` -> `content`)
3. Удалить документ (`delete`)
4. Проверить список (`trips/{trip_id}`)
