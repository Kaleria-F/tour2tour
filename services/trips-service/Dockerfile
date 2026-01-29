FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir poetry==2.0.0
COPY pyproject.toml /app/pyproject.toml
RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-interaction --no-ansi

COPY app /app/app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
