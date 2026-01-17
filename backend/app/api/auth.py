from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, or_

from app.db.deps import get_db
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse
from app.core.security import hash_password, verify_password, create_access_token
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


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
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "email": user.email, "phone": user.phone, "role": user.role}


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Нужно указать email или phone")

    stmt = select(User).where(
        or_(
            User.email == str(payload.email) if payload.email else False,
            User.phone == payload.phone if payload.phone else False,
        )
    )
    user = db.execute(stmt).scalars().first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверные учетные данные")

    token = create_access_token(sub=str(user.id), secret=settings.jwt_secret, alg=settings.jwt_alg)
    return TokenResponse(access_token=token)
