#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-master}"
REPO_PATH="${REPO_PATH:-/root/tour2tour}"
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-infra/.env.prod}"

cd "$REPO_PATH"

require_env() {
  local key="$1"
  if ! grep -qE "^${key}=" "$ENV_FILE"; then
    echo "[deploy] ERROR: Missing $key in $ENV_FILE"
    exit 1
  fi
}

echo "[deploy] Validating required env keys"
require_env "ORS_API_KEY"

echo "[deploy] Updating branch: $BRANCH"
git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "[deploy] Rebuilding and restarting containers"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build

echo "[deploy] Applying auth migrations"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T auth-service alembic upgrade head

echo "[deploy] Applying trips migrations"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T trips-service alembic upgrade head

echo "[deploy] Applying places migrations"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T places-service alembic upgrade head

echo "[deploy] Applying interactions migrations"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T interactions-service alembic upgrade head

echo "[deploy] Validating nginx config"
nginx -t
systemctl reload nginx

echo "[deploy] Done"
