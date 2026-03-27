from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.core.config import settings

bearer = HTTPBearer(auto_error=False)


def get_token_payload(
    cred: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> dict:
    if not cred:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        payload = jwt.decode(
            cred.credentials,
            settings.jwt_secret,
            algorithms=[settings.jwt_alg],
        )
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    if not payload.get("sub"):
        raise HTTPException(status_code=401, detail="Invalid token")
    return payload


def require_admin(payload: dict = Depends(get_token_payload)) -> dict:
    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return payload
