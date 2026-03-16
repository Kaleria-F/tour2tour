# Infra

Local environment is managed by `infra/docker-compose.yml`.

## Local services

- `gateway` -> `http://127.0.0.1:8888`
- `auth-service` -> internal Docker network only
- `trips-service` -> internal Docker network only
- `recommendations-service` -> internal Docker network only
- `payments-service` -> internal Docker network only
- `documents-service` -> internal Docker network only
- `auth-db` -> `5433`
- `trips-db` -> `5434`
- `rec-db` -> `5435`
- `payments-db` -> `5436`
- `redis` -> `6379`
- `minio` -> `9000`, `9001`

## Manual start

From repository root:
```bash
docker compose -f infra/docker-compose.yml up --build -d
docker compose -f infra/docker-compose.yml exec auth-service alembic upgrade head
docker compose -f infra/docker-compose.yml exec trips-service alembic upgrade head
```

Health check:
```bash
curl.exe http://127.0.0.1:8888/health
```

## One-command restart

From repository root:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\local-restart.ps1
```

Full reset with volume cleanup:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\local-restart.ps1 -Clean
```

Restart + auto-start Flutter Web:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\local-restart.ps1 -RunWeb
```

## Manual cleanup

Stop only:
```bash
docker compose -f infra/docker-compose.yml down
```

Stop and remove volumes:
```bash
docker compose -f infra/docker-compose.yml down -v
```
