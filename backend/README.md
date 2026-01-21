# Backend (FastAPI)

## Структура проекта

Ниже кратко описано, где что находится, чтобы быстро ориентироваться в коде.

### Точка входа и роутеры

- `app/main.py` — создание `FastAPI`, подключение роутеров и health-check.
- `app/api/` — HTTP-эндпоинты.
  - `auth.py` — регистрация и логин.
  - `users.py` — эндпоинты профиля и предпочтений.
  - `deps.py` — зависимости API (получение текущего пользователя).

### Конфигурация и безопасность

- `app/core/config.py` — загрузка настроек из `backend/.env`.
- `app/core/security.py` — хэширование паролей и создание JWT.

### База данных

- `app/db/session.py` — инициализация `SQLAlchemy` сессии.
- `app/db/deps.py` — зависимость `get_db`.
- `app/db/base.py` — базовый класс моделей.

### Модели и схемы

- `app/models/` — SQLAlchemy модели.
  - `user.py` — пользователи.
  - `user_preferences.py` — предпочтения пользователя.
- `app/schemas/` — Pydantic схемы для API.
  - `auth.py` — вход/регистрация и токен.
  - `preferences.py` — предпочтения.

### Миграции

- `alembic/` — миграции базы данных.
- `alembic.ini` — конфиг Alembic.
- `alembic/versions/` — версии миграций.

### Зависимости и сборка

- `pyproject.toml`, `poetry.lock` — зависимости Python и управление окружением (Poetry).
