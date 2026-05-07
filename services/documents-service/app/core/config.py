from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Annotated


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
    s3_presign_ttl_seconds: int = Field(default=300, alias="S3_PRESIGN_TTL_SECONDS")
    s3_sse_mode: str | None = Field(default="AES256", alias="S3_SSE_MODE")
    s3_cors_allowed_origins: Annotated[list[str], Field(default_factory=lambda: ["*"], alias="S3_CORS_ALLOWED_ORIGINS")]

    database_url: str = Field(alias="DATABASE_URL")
    max_upload_size_bytes: int = Field(default=15 * 1024 * 1024, alias="MAX_UPLOAD_SIZE_BYTES")
    enable_upload_scan: bool = Field(default=False, alias="ENABLE_UPLOAD_SCAN")

    model_config = SettingsConfigDict(extra="ignore")


settings = Settings()
