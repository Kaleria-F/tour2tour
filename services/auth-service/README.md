# Auth Service

Отвечает за регистрацию, логин, профиль и предпочтения пользователя.

## Запуск (локально)
1. Установить зависимости (Poetry).
2. Создать `.env` рядом с `pyproject.toml`.
3. Запустить `uvicorn app.main:app --app-dir services/auth-service --reload`.
