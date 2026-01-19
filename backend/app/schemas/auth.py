from pydantic import BaseModel, EmailStr, field_validator
import re

PASSWORD_ALLOWED_SPECIALS = r"""~!?@#$%^&*_-\+()\[\]{}><\/\\|"'\.,:"""

class RegisterRequest(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str):
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
            raise ValueError("Пароль должен содержать минимум 1 спецсимвол из разрешённого набора")
        return v

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    password: str
