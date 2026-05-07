from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionLocal

bearer = HTTPBearer(auto_error=False)


def get_current_user_id(
    cred: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> int:
    if not cred:
        raise HTTPException(status_code=401, detail="Not authenticated")

    token = cred.credentials
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_alg])
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=401, detail="Invalid token")
        return int(sub)
    except (JWTError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token")


def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
