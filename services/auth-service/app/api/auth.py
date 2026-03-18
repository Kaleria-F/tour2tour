from __future__ import annotations

import logging
import secrets
from datetime import datetime, timedelta, timezone

import pyotp
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.mailer import send_email
from app.core.security import create_access_token, hash_password, verify_password
from app.db.deps import get_db
from app.models.user import User
from app.schemas.auth import (
    AuthStatusOut,
    ChangePasswordCodeRequest,
    ChangePasswordRequest,
    LoginRequest,
    RecoveryConfirmRequest,
    RecoveryRequest,
    RegisterRequest,
    StepUpChallengeOut,
    StepUpVerifyRequest,
    TokenResponse,
    TotpEnableRequest,
    TotpSetupResponse,
    TwoFactorVerifyRequest,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)

_LOGIN_CHALLENGES: dict[str, dict] = {}
_STEP_UP_CHALLENGES: dict[str, dict] = {}
_RECOVERY_CODES: dict[str, dict] = {}
_CHANGE_PASSWORD_CODES: dict[str, dict] = {}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _cleanup_expired() -> None:
    now = _utc_now()
    for storage in (_LOGIN_CHALLENGES, _STEP_UP_CHALLENGES, _RECOVERY_CODES, _CHANGE_PASSWORD_CODES):
        expired = [key for key, value in storage.items() if value["expires_at"] < now]
        for key in expired:
            storage.pop(key, None)


def _find_user(payload: LoginRequest, db: Session) -> User | None:
    stmt = select(User).where(
        or_(
            User.email == str(payload.email) if payload.email else False,
            User.phone == payload.phone if payload.phone else False,
        )
    )
    return db.execute(stmt).scalars().first()


def _issue_access_token(user: User) -> TokenResponse:
    token = create_access_token(sub=str(user.id), secret=settings.jwt_secret, alg=settings.jwt_alg)
    return TokenResponse(access_token=token)


def _send_email_safely(to_email: str, subject: str, body: str) -> None:
    try:
        send_email(to_email=to_email, subject=subject, body=body)
        logger.info("Email sent to %s", to_email)
    except Exception:
        logger.exception("Failed to send email to %s", to_email)


@router.post("/register")
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Нужно указать email или phone")

    stmt = select(User).where(
        or_(
            User.email == str(payload.email) if payload.email else False,
            User.phone == payload.phone if payload.phone else False,
        )
    )
    existing = db.execute(stmt).scalars().first()
    if existing:
        raise HTTPException(status_code=409, detail="Пользователь уже существует")

    user = User(
        email=str(payload.email) if payload.email else None,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
        role="traveler",
        is_2fa_enabled=False,
        totp_enabled=False,
        passkey_enabled=False,
        totp_secret=None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {
        "id": user.id,
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "security_setup_required": True,
    }


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    _cleanup_expired()
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Нужно указать email или phone")

    user = _find_user(payload, db)
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверные учетные данные")

    factors: list[str] = []
    if user.passkey_enabled:
        factors.append("passkey")
    if user.totp_enabled:
        factors.append("totp")

    if factors:
        challenge_id = secrets.token_urlsafe(24)
        _LOGIN_CHALLENGES[challenge_id] = {
            "user_id": user.id,
            "factors": factors,
            "expires_at": _utc_now() + timedelta(minutes=5),
        }
        return TokenResponse(
            requires_2fa=True,
            challenge_id=challenge_id,
            available_factors=factors,
        )

    return _issue_access_token(user)


@router.post("/2fa/verify", response_model=TokenResponse)
def verify_second_factor(payload: TwoFactorVerifyRequest, db: Session = Depends(get_db)):
    _cleanup_expired()
    challenge = _LOGIN_CHALLENGES.get(payload.challenge_id)
    if not challenge:
        raise HTTPException(status_code=400, detail="Сессия подтверждения истекла")

    user = db.execute(select(User).where(User.id == challenge["user_id"])).scalars().first()
    if not user:
        _LOGIN_CHALLENGES.pop(payload.challenge_id, None)
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if "totp" not in challenge["factors"]:
        raise HTTPException(status_code=400, detail="TOTP для пользователя не настроен")
    if not user.totp_secret:
        raise HTTPException(status_code=400, detail="TOTP секрет отсутствует")

    if not pyotp.TOTP(user.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Неверный код")

    _LOGIN_CHALLENGES.pop(payload.challenge_id, None)
    return _issue_access_token(user)


@router.get("/security/status", response_model=AuthStatusOut)
def security_status(me: User = Depends(get_current_user)):
    return AuthStatusOut(
        passkey_enabled=me.passkey_enabled,
        totp_enabled=me.totp_enabled,
        second_factor_required=me.is_2fa_enabled,
    )


@router.post("/totp/setup", response_model=TotpSetupResponse)
def totp_setup(me: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if me.totp_enabled and me.totp_secret:
        secret = me.totp_secret
    else:
        secret = pyotp.random_base32()
        me.totp_secret = secret
        db.add(me)
        db.commit()
        db.refresh(me)
    account_name = me.email or me.phone or f"user-{me.id}"
    otpauth_uri = pyotp.TOTP(secret).provisioning_uri(
        name=account_name,
        issuer_name="Tour2Tour",
    )
    return TotpSetupResponse(secret=secret, otpauth_uri=otpauth_uri)


@router.post("/totp/enable", response_model=AuthStatusOut)
def totp_enable(
    payload: TotpEnableRequest,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not me.totp_secret:
        raise HTTPException(status_code=400, detail="Сначала выполните /auth/totp/setup")
    if not pyotp.TOTP(me.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Неверный код")

    me.totp_enabled = True
    me.is_2fa_enabled = me.totp_enabled or me.passkey_enabled
    db.add(me)
    db.commit()
    db.refresh(me)
    return AuthStatusOut(
        passkey_enabled=me.passkey_enabled,
        totp_enabled=me.totp_enabled,
        second_factor_required=me.is_2fa_enabled,
    )


@router.post("/totp/disable", response_model=AuthStatusOut)
def totp_disable(
    payload: TotpEnableRequest,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if me.totp_enabled and me.totp_secret:
        if not pyotp.TOTP(me.totp_secret).verify(payload.code, valid_window=1):
            raise HTTPException(status_code=401, detail="Неверный код")
    me.totp_enabled = False
    me.totp_secret = None
    me.is_2fa_enabled = me.passkey_enabled
    db.add(me)
    db.commit()
    db.refresh(me)
    return AuthStatusOut(
        passkey_enabled=me.passkey_enabled,
        totp_enabled=me.totp_enabled,
        second_factor_required=me.is_2fa_enabled,
    )


@router.post("/passkey/enable", response_model=AuthStatusOut)
def passkey_enable(me: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Placeholder until WebAuthn registration flow is implemented.
    me.passkey_enabled = True
    me.is_2fa_enabled = me.totp_enabled or me.passkey_enabled
    db.add(me)
    db.commit()
    db.refresh(me)
    return AuthStatusOut(
        passkey_enabled=me.passkey_enabled,
        totp_enabled=me.totp_enabled,
        second_factor_required=me.is_2fa_enabled,
    )


@router.post("/passkey/disable", response_model=AuthStatusOut)
def passkey_disable(me: User = Depends(get_current_user), db: Session = Depends(get_db)):
    me.passkey_enabled = False
    me.is_2fa_enabled = me.totp_enabled or me.passkey_enabled
    db.add(me)
    db.commit()
    db.refresh(me)
    return AuthStatusOut(
        passkey_enabled=me.passkey_enabled,
        totp_enabled=me.totp_enabled,
        second_factor_required=me.is_2fa_enabled,
    )


@router.post("/step-up/challenge", response_model=StepUpChallengeOut)
def step_up_challenge(me: User = Depends(get_current_user)):
    _cleanup_expired()
    factors: list[str] = []
    if me.passkey_enabled:
        factors.append("passkey")
    if me.totp_enabled:
        factors.append("totp")
    if not factors:
        raise HTTPException(status_code=400, detail="Дополнительный фактор не настроен")

    challenge_id = secrets.token_urlsafe(24)
    _STEP_UP_CHALLENGES[challenge_id] = {
        "user_id": me.id,
        "factors": factors,
        "expires_at": _utc_now() + timedelta(minutes=5),
    }
    return StepUpChallengeOut(challenge_id=challenge_id, available_factors=factors)


@router.post("/step-up/verify", response_model=TokenResponse)
def step_up_verify(
    payload: StepUpVerifyRequest,
    me: User = Depends(get_current_user),
):
    _cleanup_expired()
    challenge = _STEP_UP_CHALLENGES.get(payload.challenge_id)
    if not challenge or challenge["user_id"] != me.id:
        raise HTTPException(status_code=400, detail="Step-up challenge недействителен")
    if "totp" not in challenge["factors"] or not me.totp_secret:
        raise HTTPException(status_code=400, detail="TOTP недоступен для подтверждения")
    if not pyotp.TOTP(me.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Неверный код")

    _STEP_UP_CHALLENGES.pop(payload.challenge_id, None)
    token = create_access_token(
        sub=str(me.id),
        secret=settings.jwt_secret,
        alg=settings.jwt_alg,
        expires_minutes=10,
        extra_claims={"step_up": True},
    )
    return TokenResponse(access_token=token)


@router.post("/recovery/request")
def recovery_request(
    payload: RecoveryRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    _cleanup_expired()
    user = db.execute(select(User).where(User.email == str(payload.email))).scalars().first()
    if not user:
        # Do not reveal if account exists.
        return {"ok": True}

    code = f"{secrets.randbelow(900000) + 100000}"
    _RECOVERY_CODES[str(payload.email).lower()] = {
        "user_id": user.id,
        "code": code,
        "expires_at": _utc_now() + timedelta(minutes=10),
    }
    background_tasks.add_task(
        _send_email_safely,
        to_email=str(payload.email),
        subject="Tour2Tour: код восстановления доступа",
        body=f"Ваш код восстановления: {code}\nКод действует 10 минут.",
    )
    return {"ok": True}


@router.post("/recovery/confirm")
def recovery_confirm(payload: RecoveryConfirmRequest, db: Session = Depends(get_db)):
    _cleanup_expired()
    key = str(payload.email).lower()
    record = _RECOVERY_CODES.get(key)
    if not record or record["code"] != payload.code:
        raise HTTPException(status_code=400, detail="Неверный или просроченный код восстановления")

    user = db.execute(select(User).where(User.id == record["user_id"])).scalars().first()
    if not user:
        _RECOVERY_CODES.pop(key, None)
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if user.phone:
        if not payload.phone_last4 or not user.phone.endswith(payload.phone_last4):
            raise HTTPException(status_code=400, detail="Не пройдена дополнительная проверка телефона")

    user.password_hash = hash_password(payload.new_password)
    # Recovery resets second factors to prevent account lockout.
    user.totp_enabled = False
    user.totp_secret = None
    user.passkey_enabled = False
    user.is_2fa_enabled = False
    db.add(user)
    db.commit()
    _RECOVERY_CODES.pop(key, None)
    return {"ok": True}


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.current_password, me.password_hash):
        raise HTTPException(status_code=401, detail="Текущий пароль неверный")
    if verify_password(payload.new_password, me.password_hash):
        raise HTTPException(status_code=400, detail="Новый пароль должен отличаться от текущего")

    if me.is_2fa_enabled:
        is_totp_ok = False
        if payload.totp_code and me.totp_secret:
            is_totp_ok = pyotp.TOTP(me.totp_secret).verify(payload.totp_code, valid_window=1)

        is_email_code_ok = False
        if payload.email_code:
            code_record = _CHANGE_PASSWORD_CODES.get(str(me.id))
            if code_record and code_record["code"] == payload.email_code:
                is_email_code_ok = True
                _CHANGE_PASSWORD_CODES.pop(str(me.id), None)

        if not is_totp_ok and not is_email_code_ok:
            raise HTTPException(
                status_code=401,
                detail="Требуется корректный код второго фактора (TOTP или email-код)",
            )

    me.password_hash = hash_password(payload.new_password)
    db.add(me)
    db.commit()
    return {"ok": True}


@router.post("/change-password/request-code")
def request_change_password_code(
    _: ChangePasswordCodeRequest,
    background_tasks: BackgroundTasks,
    me: User = Depends(get_current_user),
):
    if not me.email:
        raise HTTPException(status_code=400, detail="Для аккаунта не задан email")
    code = f"{secrets.randbelow(900000) + 100000}"
    _CHANGE_PASSWORD_CODES[str(me.id)] = {
        "code": code,
        "expires_at": _utc_now() + timedelta(minutes=10),
    }
    background_tasks.add_task(
        _send_email_safely,
        to_email=me.email,
        subject="Tour2Tour: код для смены пароля",
        body=f"Ваш код подтверждения смены пароля: {code}\nКод действует 10 минут.",
    )
    return {"ok": True}
