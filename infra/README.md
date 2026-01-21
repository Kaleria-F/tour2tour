# Infra

## Структура проекта

### Docker Compose

- `docker-compose.yml` — локальная инфраструктура для разработки.
  - `db` — PostgreSQL 16 (порт 5432, данные в томе `db_data`).
  - `redis` — Redis 7 (порт 6379).
