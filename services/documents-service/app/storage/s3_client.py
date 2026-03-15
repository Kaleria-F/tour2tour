import uuid

import boto3
from botocore.client import Config

from app.core.config import settings


def build_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        use_ssl=settings.s3_use_ssl,
        config=Config(s3={"addressing_style": "path" if settings.s3_force_path_style else "auto"}),
    )


def ensure_bucket_exists(s3_client) -> None:
    bucket = settings.s3_bucket
    existing = [item["Name"] for item in s3_client.list_buckets().get("Buckets", [])]
    if bucket in existing:
        return

    if settings.s3_region == "us-east-1":
        s3_client.create_bucket(Bucket=bucket)
    else:
        s3_client.create_bucket(
            Bucket=bucket,
            CreateBucketConfiguration={"LocationConstraint": settings.s3_region},
        )


def build_object_key(user_id: int, trip_id: int, original_file_name: str) -> str:
    safe_name = original_file_name.replace("\\", "_").replace("/", "_").strip()
    return f"users/{user_id}/trips/{trip_id}/{uuid.uuid4()}-{safe_name}"
