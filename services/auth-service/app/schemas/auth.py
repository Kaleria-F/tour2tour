from pydantic import BaseModel, EmailStr, field_validator
import re

PASSWORD_ALLOWED_SPECIALS = r"""~!?@#$%^&*_-\+()\[\]{}><\/\\|"'\.,:"""


def validate_password_strength(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Пароль должен быть не менее 8 символов")
    if len(v.encode("utf-8")) > 72:
        raise ValueError("Пароль слишком длинный (bcrypt поддерживает до 72 байт)")
    if not re.search(r"[A-Z]", v):
        raise ValueError("Пароль должен содержать минимум 1 заглавную латинскую букву")
    if not re.search(r"[a-z]", v):
        raise ValueError("Пароль должен содержать минимум 1 строчную латинскую букву")
    if not re.search(r"\d", v):
        raise ValueError("Пароль должен содержать минимум 1 цифру")
    if not re.search(f"[{re.escape(PASSWORD_ALLOWED_SPECIALS)}]", v):
        raise ValueError("Пароль должен содержать минимум 1 спецсимвол из разрешенного набора")
    return v


class RegisterRequest(BaseModel):
    email: EmailStr
    code: str


class RegisterCodeRequest(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str):
        return validate_password_strength(v)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, v: str | None):
        if v is None:
            return None
        digits = re.sub(r"\D", "", v)
        if not digits:
            return None
        if len(digits) == 11 and digits.startswith("8"):
            digits = "7" + digits[1:]
        if len(digits) == 10:
            digits = "7" + digits
        if len(digits) != 11 or not digits.startswith("7"):
            raise ValueError("Некорректный формат телефона")
        return f"+{digits}"


class TokenResponse(BaseModel):
    access_token: str | None = None
    token_type: str = "bearer"
    requires_2fa: bool = False
    challenge_id: str | None = None
    available_factors: list[str] = []


class LoginRequest(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    password: str


class TwoFactorVerifyRequest(BaseModel):
    challenge_id: str
    code: str


class TotpSetupResponse(BaseModel):
    secret: str
    otpauth_uri: str


class TotpEnableRequest(BaseModel):
    code: str


class AuthStatusOut(BaseModel):
    passkey_enabled: bool
    totp_enabled: bool
    second_factor_required: bool


class StepUpChallengeOut(BaseModel):
    challenge_id: str
    available_factors: list[str]


class StepUpVerifyRequest(BaseModel):
    challenge_id: str
    code: str


class RecoveryRequest(BaseModel):
    email: EmailStr


class RecoveryConfirmRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str):
        return validate_password_strength(v)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str
    totp_code: str | None = None
    email_code: str | None = None

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str):
        return validate_password_strength(v)


class ChangePasswordCodeRequest(BaseModel):
    pass
