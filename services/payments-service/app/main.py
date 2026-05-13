from __future__ import annotations

import logging
from uuid import uuid4

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.schemas.payment import (
    PaymentStatusOut,
    ProCheckoutCreateIn,
    ProCheckoutCreateOut,
)

logger = logging.getLogger(__name__)

app = FastAPI(title="Tour2Tour Payments Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8000",
        "https://24tour2tour.ru",
        "https://api.24tour2tour.ru",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _assert_yookassa_configured() -> None:
    if not settings.yookassa_shop_id.strip() or not settings.yookassa_secret_key.strip():
        raise HTTPException(
            status_code=503,
            detail="YooKassa is not configured.",
        )


def _http_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(timeout=20.0)


def _yookassa_auth() -> tuple[str, str]:
    return (settings.yookassa_shop_id, settings.yookassa_secret_key)


def _build_return_url(override: str | None) -> str:
    value = (override or "").strip()
    return value or settings.yookassa_return_url.strip()


def _extract_error_detail(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return response.text[:500] or "Unknown YooKassa error"
    description = payload.get("description")
    if isinstance(description, str) and description.strip():
        return description.strip()
    error = payload.get("type") or payload.get("code")
    if isinstance(error, str) and error.strip():
        return error.strip()
    return str(payload)[:500]


async def _fetch_payment(payment_id: str) -> dict:
    _assert_yookassa_configured()
    async with _http_client() as client:
        response = await client.get(
            f"{settings.yookassa_api_base_url.rstrip('/')}/payments/{payment_id}",
            auth=_yookassa_auth(),
        )
    if response.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa payment lookup failed: {_extract_error_detail(response)}",
        )
    return response.json()


async def _grant_premium(user_id: int) -> None:
    token = settings.internal_service_token.strip()
    if not token:
        raise HTTPException(
            status_code=503,
            detail="Internal premium activation token is not configured.",
        )
    async with _http_client() as client:
        response = await client.post(
            f"{settings.auth_service_url.rstrip('/')}/users/internal/users/{user_id}/premium",
            headers={"X-Internal-Token": token},
            json={"is_premium": True, "duration_days": 30},
        )
    if response.status_code >= 400:
        logger.error(
            "Premium activation failed for user %s: %s %s",
            user_id,
            response.status_code,
            response.text,
        )
        raise HTTPException(
            status_code=502,
            detail="Failed to activate premium subscription.",
        )


def _payment_status_out(payment: dict, *, is_premium_activated: bool) -> PaymentStatusOut:
    amount = payment.get("amount") if isinstance(payment.get("amount"), dict) else {}
    confirmation = (
        payment.get("confirmation") if isinstance(payment.get("confirmation"), dict) else {}
    )
    return PaymentStatusOut(
        payment_id=str(payment.get("id", "")),
        status=str(payment.get("status", "")),
        paid=bool(payment.get("paid")),
        is_premium_activated=is_premium_activated,
        amount_value=amount.get("value"),
        currency=amount.get("currency"),
        confirmation_url=confirmation.get("confirmation_url"),
        is_test=payment.get("test") if isinstance(payment.get("test"), bool) else None,
    )


@app.post("/payments/pro/checkout", response_model=ProCheckoutCreateOut)
async def create_pro_checkout(
    payload: ProCheckoutCreateIn,
    user_id: int = Depends(get_current_user_id),
):
    _assert_yookassa_configured()
    return_url = _build_return_url(payload.return_url)
    if not return_url.startswith("https://") and not return_url.startswith("http://localhost"):
        raise HTTPException(status_code=400, detail="Return URL must be HTTPS.")

    request_body = {
        "amount": {
            "value": settings.premium_amount_rub,
            "currency": "RUB",
        },
        "capture": True,
        "confirmation": {
            "type": "redirect",
            "return_url": return_url,
        },
        "description": settings.premium_description,
        "metadata": {
            "user_id": str(user_id),
            "plan": "tour2tour_pro",
            "source": (payload.source or "premium_page").strip() or "premium_page",
        },
    }
    headers = {"Idempotence-Key": str(uuid4())}

    async with _http_client() as client:
        response = await client.post(
            f"{settings.yookassa_api_base_url.rstrip('/')}/payments",
            auth=_yookassa_auth(),
            headers=headers,
            json=request_body,
        )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"YooKassa payment creation failed: {_extract_error_detail(response)}",
        )

    data = response.json()
    confirmation = data.get("confirmation") if isinstance(data.get("confirmation"), dict) else {}
    confirmation_url = confirmation.get("confirmation_url")
    if not isinstance(confirmation_url, str) or not confirmation_url.strip():
        raise HTTPException(
            status_code=502,
            detail="YooKassa did not return a confirmation URL.",
        )
    amount = data.get("amount") if isinstance(data.get("amount"), dict) else {}
    return ProCheckoutCreateOut(
        payment_id=str(data.get("id", "")),
        status=str(data.get("status", "")),
        confirmation_url=confirmation_url,
        amount_value=str(amount.get("value", settings.premium_amount_rub)),
        currency=str(amount.get("currency", "RUB")),
        is_test=data.get("test") if isinstance(data.get("test"), bool) else None,
    )


@app.get("/payments/pro/{payment_id}", response_model=PaymentStatusOut)
async def get_pro_payment_status(
    payment_id: str,
    user_id: int = Depends(get_current_user_id),
):
    payment = await _fetch_payment(payment_id)
    metadata = payment.get("metadata") if isinstance(payment.get("metadata"), dict) else {}
    payment_user_id = str(metadata.get("user_id", "")).strip()
    if payment_user_id != str(user_id):
        raise HTTPException(status_code=403, detail="This payment belongs to another user.")

    is_premium_activated = False
    if payment.get("status") == "succeeded" and bool(payment.get("paid")):
        await _grant_premium(user_id)
        is_premium_activated = True

    return _payment_status_out(payment, is_premium_activated=is_premium_activated)


@app.post("/payments/yookassa/webhook")
async def yookassa_webhook(request: Request):
    payload = await request.json()
    if payload.get("type") != "notification":
        return {"status": "ignored"}

    event = str(payload.get("event", ""))
    obj = payload.get("object") if isinstance(payload.get("object"), dict) else {}
    payment_id = str(obj.get("id", "")).strip()
    if not payment_id:
        return {"status": "ignored"}

    if event not in {"payment.succeeded", "payment.waiting_for_capture", "payment.canceled"}:
        return {"status": "ignored"}

    if event == "payment.succeeded":
        payment = await _fetch_payment(payment_id)
        metadata = payment.get("metadata") if isinstance(payment.get("metadata"), dict) else {}
        payment_user_id = str(metadata.get("user_id", "")).strip()
        if payment.get("status") == "succeeded" and bool(payment.get("paid")) and payment_user_id.isdigit():
            await _grant_premium(int(payment_user_id))
            return {"status": "premium_activated", "payment_id": payment_id}

    return {"status": "ok", "payment_id": payment_id}


@app.get("/payments/status")
def payment_status():
    return {
        "status": "ok",
        "provider": "yookassa",
        "configured": bool(
            settings.yookassa_shop_id.strip() and settings.yookassa_secret_key.strip()
        ),
    }


@app.get("/health")
def health():
    return {"status": "ok"}
