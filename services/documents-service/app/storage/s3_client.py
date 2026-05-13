import uuid

import boto3
from botocore.client import Config

from app.core.config import settings


def get_s3_client():
    style = "path" if settings.s3_force_path_style else "virtual"
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        use_ssl=settings.s3_use_ssl,
        verify=settings.s3_verify_ssl,
        config=Config(signature_version="s3v4", s3={"addressing_style": style}),
    )


def build_object_key(*, user_id: int, trip_id: int, file_name: str) -> str:
    safe_name = file_name.replace("\\", "_").replace("/", "_").strip()
    return f"users/{user_id}/trips/{trip_id}/{uuid.uuid4()}__{safe_name}"
