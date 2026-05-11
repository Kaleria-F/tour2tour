from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ENV_PATH = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    jwt_secret: str = Field(alias="JWT_SECRET")
    jwt_alg: str = Field(default="HS256", alias="JWT_ALG")
    auth_service_url: str = Field(
        default="http://auth-service:8000",
        alias="AUTH_SERVICE_URL",
    )
    internal_service_token: str = Field(default="", alias="INTERNAL_SERVICE_TOKEN")
    yookassa_shop_id: str = Field(default="", alias="YOOKASSA_SHOP_ID")
    yookassa_secret_key: str = Field(default="", alias="YOOKASSA_SECRET_KEY")
    yookassa_api_base_url: str = Field(
        default="https://api.yookassa.ru/v3",
        alias="YOOKASSA_API_BASE_URL",
    )
    yookassa_return_url: str = Field(
        default="https://24tour2tour.ru/premium",
        alias="YOOKASSA_RETURN_URL",
    )
    premium_amount_rub: str = Field(default="299.00", alias="PREMIUM_AMOUNT_RUB")
    premium_description: str = Field(
        default="Подписка Тур2Тур Pro",
        alias="PREMIUM_DESCRIPTION",
    )

    model_config = SettingsConfigDict(
        env_file=str(ENV_PATH),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
