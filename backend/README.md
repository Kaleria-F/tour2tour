# Backend (legacy monolith)

Этот каталог содержит исходный монолитный FastAPI (legacy).
Для новой микросервисной архитектуры используйте `services/`.

## Что где находится (legacy)
- `backend/app/main.py` — создание `FastAPI`, подключение роутеров и health-check.
- `backend/app/api/` — HTTP-эндпоинты (auth/users/trips).
- `backend/app/core/` — конфигурация и безопасность.
- `backend/app/db/` — подключение к БД и базовые зависимости.
- `backend/app/models/` — SQLAlchemy модели.
- `backend/app/schemas/` — Pydantic схемы.
- `backend/alembic/` — миграции БД.
