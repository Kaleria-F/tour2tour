import re

from pydantic import BaseModel, EmailStr, field_validator


class UserMeOut(BaseModel):
    id: int
    email: str | None
    phone: str | None
    display_name: str | None
    avatar_url: str | None
    is_premium: bool
    role: str
    is_2fa_enabled: bool
    totp_enabled: bool
    passkey_enabled: bool


class UserProfileUpdateIn(BaseModel):
    display_name: str | None = None
    phone: str | None = None
    avatar_url: str | None = None

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("Display name is required.")
        if len(normalized) > 128:
            raise ValueError("Display name is too long.")
        return normalized

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        digits = re.sub(r"\D", "", value)
        if not digits:
            return None
        if len(digits) == 11 and digits.startswith("8"):
            digits = "7" + digits[1:]
        if len(digits) == 10:
            digits = "7" + digits
        if len(digits) != 11 or not digits.startswith("7"):
            raise ValueError("Invalid phone format.")
        return f"+{digits}"

    @field_validator("avatar_url")
    @classmethod
    def validate_avatar_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            return None
        if len(normalized) > 3_000_000:
            raise ValueError("Avatar payload is too large.")
        return normalized


class EmailChangeRequestIn(BaseModel):
    new_email: EmailStr


class EmailChangeConfirmIn(BaseModel):
    new_email: EmailStr
    code: str


class StageAssistantTrialOut(BaseModel):
    limit: int
    used: int
    remaining: int
    is_locked: bool


class PremiumGrantIn(BaseModel):
    is_premium: bool = True
