# Documents Service

Сервис выдает безопасные `presigned URL` для загрузки и скачивания документов в S3/MinIO.

Текущий MVP:
- Проверка JWT (`Bearer token`).
- Создание bucket при старте (`/documents/storage/ensure-bucket`).
- Выдача `upload URL` и `download URL`.

Следующий шаг после MVP:
- Добавить PostgreSQL и хранить метаданные документов (`trip_id`, owner, имя файла, размер, статус).
