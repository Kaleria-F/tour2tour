import uuid

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError

from app.core.config import settings


def _build_s3_client(endpoint_url: str, addressing_style: str | None = None):
    style = addressing_style or ("path" if settings.s3_force_path_style else "virtual")
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        use_ssl=settings.s3_use_ssl,
        verify=settings.s3_verify_ssl,
        config=Config(s3={"addressing_style": style}),
    )


def get_object_storage_client():
    return _build_s3_client(settings.s3_endpoint)


def get_presign_client():
    endpoint = settings.s3_public_endpoint or settings.s3_endpoint
    return _build_s3_client(endpoint)


def get_object_storage_client_with_style(addressing_style: str):
    return _build_s3_client(settings.s3_endpoint, addressing_style=addressing_style)


def ensure_bucket_exists(s3_client) -> None:
    try:
        s3_client.head_bucket(Bucket=settings.s3_bucket)
        return
    except ClientError as exc:
        code = str((exc.response.get("Error") or {}).get("Code") or "")
        # Bucket exists but credentials cannot perform HeadBucket/ListBuckets.
        # For managed S3 providers this is common; continue and let put/get fail
        # later with a precise object-level error if access is really denied.
        if code in {"403", "AccessDenied"}:
            return
        # Bucket does not exist or cannot be found for this account/region.
        if code not in {"404", "NoSuchBucket", "NotFound"}:
            raise

    if settings.s3_region == "us-east-1":
        s3_client.create_bucket(Bucket=settings.s3_bucket)
    else:
        s3_client.create_bucket(
            Bucket=settings.s3_bucket,
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
        return


def make_object_key(*, user_id: int, trip_id: int, file_name: str) -> str:
    safe_name = file_name.replace("\\", "_").replace("/", "_").strip()
    return f"users/{user_id}/trips/{trip_id}/{uuid.uuid4()}__{safe_name}"
