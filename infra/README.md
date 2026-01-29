# Infra

## Docker Compose

`infra/docker-compose.yml` — локальная инфраструктура для микросервисов.

Сервисы:
- `auth-service` (порт `8001`) + `auth-db` (порт `5433`).
- `trips-service` (порт `8002`) + `trips-db` (порт `5434`).
- `recommendations-service` (порт `8003`) + `rec-db` (порт `5435`) + `redis` (порт `6379`).
- `payments-service` (порт `8004`) + `payments-db` (порт `5436`).

### Быстрый старт
```
docker compose -f infra/docker-compose.yml up --build
```
