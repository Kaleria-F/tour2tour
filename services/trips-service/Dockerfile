FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir poetry==2.0.0
COPY pyproject.toml /app/pyproject.toml
COPY README.md /app/README.md
RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-interaction --no-ansi --no-root

COPY app /app/app
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
