from pydantic import BaseModel


class UserMeOut(BaseModel):
    id: int
    email: str | None
    phone: str | None
    role: str
    is_2fa_enabled: bool
    totp_enabled: bool
    passkey_enabled: bool
