from __future__ import annotations

import logging
import secrets

import pyotp
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core import auth_state
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

LOGIN_CHALLENGE_TTL = 5 * 60
STEP_UP_CHALLENGE_TTL = 5 * 60
RECOVERY_CODE_TTL = 10 * 60
CHANGE_PASSWORD_CODE_TTL = 10 * 60


def _normalize_email(email: str | None) -> str:
    return (email or "").strip().lower()


def _request_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "").strip()
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _login_challenge_key(challenge_id: str) -> str:
    return f"auth:login-challenge:{challenge_id}"


def _step_up_challenge_key(challenge_id: str) -> str:
    return f"auth:step-up-challenge:{challenge_id}"


def _recovery_code_key(email: str) -> str:
    return f"auth:recovery-code:{_normalize_email(email)}"


def _change_password_code_key(user_id: int) -> str:
    return f"auth:change-password-code:{user_id}"


def _rate_limit_or_ignore(key: str, limit: int, window_seconds: int) -> None:
    try:
        auth_state.check_rate_limit(key, limit=limit, window_seconds=window_seconds)
    except ValueError:
        raise HTTPException(status_code=429, detail="Too many requests. Please try again later.")
    except RuntimeError:
        logger.exception("Rate limiter unavailable for key %s", key)


def _state_read_or_503(key: str) -> dict | None:
    try:
        return auth_state.get_json(key)
    except RuntimeError:
        logger.exception("Redis read failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _state_write_or_503(key: str, value: dict, ttl_seconds: int) -> None:
    try:
        auth_state.set_json(key, value, ttl_seconds=ttl_seconds)
    except RuntimeError:
        logger.exception("Redis write failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _state_delete_or_503(key: str) -> None:
    try:
        auth_state.delete(key)
    except RuntimeError:
        logger.exception("Redis delete failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _find_user(payload: LoginRequest, db: Session) -> User | None:
    clauses = []
    email = _normalize_email(str(payload.email) if payload.email else None)
    if email:
        clauses.append(User.email == email)
    if payload.phone:
        clauses.append(User.phone == payload.phone)
    if not clauses:
        return None
    stmt = select(User).where(or_(*clauses))
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
    email = _normalize_email(str(payload.email) if payload.email else None)
    phone = (payload.phone or "").strip() or None
    if not email and not phone:
        raise HTTPException(status_code=400, detail="Email or phone is required.")

    clauses = []
    if email:
        clauses.append(User.email == email)
    if phone:
        clauses.append(User.phone == phone)
    existing = db.execute(select(User).where(or_(*clauses))).scalars().first()
    if existing:
        raise HTTPException(status_code=409, detail="User already exists.")

    user = User(
        email=email or None,
        phone=phone,
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
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    email = _normalize_email(str(payload.email) if payload.email else None)
    principal = email or (payload.phone or "").strip()
    if not principal:
        raise HTTPException(status_code=400, detail="Email or phone is required.")

    ip = _request_ip(request)
    _rate_limit_or_ignore(f"auth:ratelimit:login:principal:{principal}", limit=10, window_seconds=300)
    _rate_limit_or_ignore(f"auth:ratelimit:login:ip:{ip}", limit=60, window_seconds=300)

    user = _find_user(payload, db)
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials.")

    factors: list[str] = []
    if user.passkey_enabled:
        factors.append("passkey")
    if user.totp_enabled:
        factors.append("totp")

    if factors:
        challenge_id = secrets.token_urlsafe(24)
        _state_write_or_503(
            _login_challenge_key(challenge_id),
            {"user_id": user.id, "factors": factors},
            ttl_seconds=LOGIN_CHALLENGE_TTL,
        )
        return TokenResponse(
            requires_2fa=True,
            challenge_id=challenge_id,
            available_factors=factors,
        )

    return _issue_access_token(user)


@router.post("/2fa/verify", response_model=TokenResponse)
def verify_second_factor(payload: TwoFactorVerifyRequest, db: Session = Depends(get_db)):
    _rate_limit_or_ignore(
        f"auth:ratelimit:2fa-verify:{payload.challenge_id}",
        limit=10,
        window_seconds=300,
    )
    challenge = _state_read_or_503(_login_challenge_key(payload.challenge_id))
    if not challenge:
        raise HTTPException(status_code=400, detail="2FA challenge expired.")

    user = db.execute(select(User).where(User.id == challenge["user_id"])).scalars().first()
    if not user:
        _state_delete_or_503(_login_challenge_key(payload.challenge_id))
        raise HTTPException(status_code=404, detail="User not found.")

    if "totp" not in challenge["factors"]:
        raise HTTPException(status_code=400, detail="TOTP is not configured for this account.")
    if not user.totp_secret:
        raise HTTPException(status_code=400, detail="TOTP secret is missing.")

    if not pyotp.TOTP(user.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Invalid code.")

    _state_delete_or_503(_login_challenge_key(payload.challenge_id))
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
        raise HTTPException(status_code=400, detail="Run /auth/totp/setup first.")
    if not pyotp.TOTP(me.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Invalid code.")

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
            raise HTTPException(status_code=401, detail="Invalid code.")
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
    _rate_limit_or_ignore(f"auth:ratelimit:step-up-challenge:{me.id}", limit=10, window_seconds=300)

    factors: list[str] = []
    if me.passkey_enabled:
        factors.append("passkey")
    if me.totp_enabled:
        factors.append("totp")
    if not factors:
        raise HTTPException(status_code=400, detail="No second factor is configured.")

    challenge_id = secrets.token_urlsafe(24)
    _state_write_or_503(
        _step_up_challenge_key(challenge_id),
        {"user_id": me.id, "factors": factors},
        ttl_seconds=STEP_UP_CHALLENGE_TTL,
    )
    return StepUpChallengeOut(challenge_id=challenge_id, available_factors=factors)


@router.post("/step-up/verify", response_model=TokenResponse)
def step_up_verify(payload: StepUpVerifyRequest, me: User = Depends(get_current_user)):
    _rate_limit_or_ignore(
        f"auth:ratelimit:step-up-verify:{payload.challenge_id}",
        limit=10,
        window_seconds=300,
    )
    challenge = _state_read_or_503(_step_up_challenge_key(payload.challenge_id))
    if not challenge or challenge["user_id"] != me.id:
        raise HTTPException(status_code=400, detail="Step-up challenge is invalid.")
    if "totp" not in challenge["factors"] or not me.totp_secret:
        raise HTTPException(status_code=400, detail="TOTP is unavailable for verification.")
    if not pyotp.TOTP(me.totp_secret).verify(payload.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Invalid code.")

    _state_delete_or_503(_step_up_challenge_key(payload.challenge_id))
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
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    email = _normalize_email(str(payload.email))
    _rate_limit_or_ignore(f"auth:ratelimit:recovery-request:email:{email}", limit=3, window_seconds=900)
    _rate_limit_or_ignore(
        f"auth:ratelimit:recovery-request:ip:{_request_ip(request)}",
        limit=20,
        window_seconds=900,
    )

    user = db.execute(select(User).where(User.email == email)).scalars().first()
    if not user:
        return {"ok": True}

    code = f"{secrets.randbelow(900000) + 100000}"
    _state_write_or_503(
        _recovery_code_key(email),
        {"user_id": user.id, "code": code},
        ttl_seconds=RECOVERY_CODE_TTL,
    )
    background_tasks.add_task(
        _send_email_safely,
        to_email=email,
        subject="Tour2Tour: recovery code",
        body=f"Your recovery code is: {code}\nThe code is valid for 10 minutes.",
    )
    return {"ok": True}


@router.post("/recovery/confirm")
def recovery_confirm(payload: RecoveryConfirmRequest, request: Request, db: Session = Depends(get_db)):
    email = _normalize_email(str(payload.email))
    _rate_limit_or_ignore(f"auth:ratelimit:recovery-confirm:{email}", limit=10, window_seconds=900)
    _rate_limit_or_ignore(
        f"auth:ratelimit:recovery-confirm-ip:{_request_ip(request)}",
        limit=30,
        window_seconds=900,
    )

    record = _state_read_or_503(_recovery_code_key(email))
    if not record or record["code"] != payload.code:
        raise HTTPException(status_code=400, detail="Recovery code is invalid or expired.")

    user = db.execute(select(User).where(User.id == record["user_id"])).scalars().first()
    if not user:
        _state_delete_or_503(_recovery_code_key(email))
        raise HTTPException(status_code=404, detail="User not found.")

    if user.phone:
        if not payload.phone_last4 or not user.phone.endswith(payload.phone_last4):
            raise HTTPException(status_code=400, detail="Additional phone verification failed.")

    user.password_hash = hash_password(payload.new_password)
    user.totp_enabled = False
    user.totp_secret = None
    user.passkey_enabled = False
    user.is_2fa_enabled = False
    db.add(user)
    db.commit()
    _state_delete_or_503(_recovery_code_key(email))
    return {"ok": True}


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.current_password, me.password_hash):
        raise HTTPException(status_code=401, detail="Current password is invalid.")
    if verify_password(payload.new_password, me.password_hash):
        raise HTTPException(status_code=400, detail="New password must differ from the current one.")

    if me.is_2fa_enabled:
        is_totp_ok = False
        if payload.totp_code and me.totp_secret:
            is_totp_ok = pyotp.TOTP(me.totp_secret).verify(payload.totp_code, valid_window=1)

        is_email_code_ok = False
        if payload.email_code:
            code_record = _state_read_or_503(_change_password_code_key(me.id))
            if code_record and code_record["code"] == payload.email_code:
                is_email_code_ok = True
                _state_delete_or_503(_change_password_code_key(me.id))

        if not is_totp_ok and not is_email_code_ok:
            raise HTTPException(
                status_code=401,
                detail="A valid second-factor code is required.",
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
        raise HTTPException(status_code=400, detail="Email is not set for this account.")
    _rate_limit_or_ignore(
        f"auth:ratelimit:change-password-request:{me.id}",
        limit=3,
        window_seconds=900,
    )

    code = f"{secrets.randbelow(900000) + 100000}"
    _state_write_or_503(
        _change_password_code_key(me.id),
        {"code": code},
        ttl_seconds=CHANGE_PASSWORD_CODE_TTL,
    )
    background_tasks.add_task(
        _send_email_safely,
        to_email=me.email,
        subject="Tour2Tour: password change code",
        body=f"Your password change code is: {code}\nThe code is valid for 10 minutes.",
    )
    return {"ok": True}
