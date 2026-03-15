from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    jwt_secret: str = Field(alias="JWT_SECRET")
    jwt_alg: str = Field(default="HS256", alias="JWT_ALG")

    s3_endpoint: str = Field(alias="S3_ENDPOINT")
    s3_public_endpoint: str | None = Field(default=None, alias="S3_PUBLIC_ENDPOINT")
    s3_region: str = Field(default="us-east-1", alias="S3_REGION")
    s3_access_key: str = Field(alias="S3_ACCESS_KEY")
    s3_secret_key: str = Field(alias="S3_SECRET_KEY")
    s3_bucket: str = Field(alias="S3_BUCKET")
    s3_use_ssl: bool = Field(default=False, alias="S3_USE_SSL")
    s3_force_path_style: bool = Field(default=True, alias="S3_FORCE_PATH_STYLE")

    model_config = SettingsConfigDict(extra="ignore")


settings = Settings()
