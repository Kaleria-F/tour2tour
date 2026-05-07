from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ENV_PATH = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    database_url: str = Field(alias="DATABASE_URL")
    jwt_secret: str = Field(alias="JWT_SECRET")
    jwt_alg: str = Field(default="HS256", alias="JWT_ALG")
    recommendations_service_url: str = Field(
        default="http://recommendations-service:8000",
        alias="RECOMMENDATIONS_SERVICE_URL",
    )
    yandex_api_key: str | None = Field(default=None, alias="YANDEX_API_KEY")
    yandex_folder_id: str | None = Field(default=None, alias="YANDEX_FOLDER_ID")
    ors_api_key: str | None = Field(default=None, alias="ORS_API_KEY")
    ors_base_url: str = Field(
        default="https://api.openrouteservice.org/v2/directions",
        alias="ORS_BASE_URL",
    )

    model_config = SettingsConfigDict(
        env_file=str(ENV_PATH),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
