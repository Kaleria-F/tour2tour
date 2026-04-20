from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ENV_PATH = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    database_url: str = Field(alias="DATABASE_URL")
    jwt_secret: str = Field(alias="JWT_SECRET", default="dev_secret")
    jwt_alg: str = Field(alias="JWT_ALG", default="HS256")
    place_images_dir: str = Field(alias="PLACE_IMAGES_DIR", default="/app/place-images")
    place_images_base_url: str = Field(alias="PLACE_IMAGES_BASE_URL", default="/media/places")
    city_data_path: str = Field(alias="CITY_DATA_PATH", default="/app/data/russian_cities.json")

    model_config = SettingsConfigDict(
        env_file=str(ENV_PATH),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
