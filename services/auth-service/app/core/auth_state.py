from __future__ import annotations

import json
from typing import Any

from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings

_redis_client: Redis | None = None


def _client() -> Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            socket_timeout=5,
            socket_connect_timeout=5,
            health_check_interval=30,
        )
    return _redis_client


def set_json(key: str, value: dict[str, Any], ttl_seconds: int) -> None:
    try:
        _client().set(key, json.dumps(value), ex=ttl_seconds)
    except RedisError as exc:
        raise RuntimeError(f"Redis unavailable while setting {key}") from exc


def get_json(key: str) -> dict[str, Any] | None:
    try:
        raw = _client().get(key)
    except RedisError as exc:
        raise RuntimeError(f"Redis unavailable while reading {key}") from exc
    if not raw:
        return None
    return json.loads(raw)


def delete(key: str) -> None:
    try:
        _client().delete(key)
    except RedisError as exc:
        raise RuntimeError(f"Redis unavailable while deleting {key}") from exc


def consume_json(key: str) -> dict[str, Any] | None:
    try:
        with _client().pipeline() as pipe:
            pipe.get(key)
            pipe.delete(key)
            raw, _ = pipe.execute()
    except RedisError as exc:
        raise RuntimeError(f"Redis unavailable while consuming {key}") from exc
    if not raw:
        return None
    return json.loads(raw)


def check_rate_limit(key: str, limit: int, window_seconds: int) -> None:
    try:
        counter = _client().incr(key)
        if counter == 1:
            _client().expire(key, window_seconds)
    except RedisError as exc:
        raise RuntimeError(f"Redis unavailable while rate limiting {key}") from exc
    if counter > limit:
        raise ValueError("rate_limit_exceeded")
