import uuid

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError

from app.core.config import settings


def _build_client(endpoint_url: str):
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        use_ssl=settings.s3_use_ssl,
        config=Config(s3={"addressing_style": "path" if settings.s3_force_path_style else "auto"}),
    )


def build_s3_client():
    return _build_client(settings.s3_endpoint)


def build_s3_presign_client():
    # Presigned URL must be signed for the same host that browser will call.
    endpoint = settings.s3_public_endpoint or settings.s3_endpoint
    return _build_client(endpoint)


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


def ensure_bucket_cors(s3_client) -> None:
    try:
        s3_client.put_bucket_cors(
            Bucket=settings.s3_bucket,
            CORSConfiguration={
                "CORSRules": [
                    {
                        "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
                        "AllowedOrigins": settings.s3_cors_allowed_origins,
                        "AllowedHeaders": ["*"],
                        "ExposeHeaders": ["ETag", "Content-Length", "Content-Type"],
                        "MaxAgeSeconds": 3600,
                    }
                ]
            },
        )
    except ClientError:
        # Some local MinIO setups may not support PutBucketCors depending on config/version.
        # Do not block document workflow if this optional step is unavailable.
        return


def build_object_key(user_id: int, trip_id: int, original_file_name: str) -> str:
    safe_name = original_file_name.replace("\\", "_").replace("/", "_").strip()
    return f"users/{user_id}/trips/{trip_id}/{uuid.uuid4()}-{safe_name}"
