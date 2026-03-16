import uuid
from urllib.parse import quote, urlparse, urlunparse

from fastapi import APIRouter, Depends, HTTPException
from botocore.exceptions import ClientError

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.schemas.document import (
    DownloadUrlRequest,
    DownloadUrlResponse,
    DocumentItemOut,
    UploadInitRequest,
    UploadInitResponse,
)
from app.storage.s3_client import (
    build_object_key,
    build_s3_client,
    build_s3_presign_client,
    ensure_bucket_cors,
    ensure_bucket_exists,
)

router = APIRouter(prefix="/documents", tags=["documents"])

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
}
URL_TTL_SECONDS = 300


def _rewrite_presigned_url(url: str) -> str:
    if not settings.s3_public_endpoint:
        return url

    src = urlparse(url)
    dst = urlparse(settings.s3_public_endpoint)
    return urlunparse(
        (
            dst.scheme or src.scheme,
            dst.netloc or src.netloc,
            src.path,
            src.params,
            src.query,
            src.fragment,
        )
    )


def _extract_visible_file_name(object_key: str) -> str:
    leaf = object_key.split("/")[-1]

    # New format support: "<uuid>__<original_name>"
    if "__" in leaf:
        maybe_uuid, maybe_name = leaf.split("__", 1)
        try:
            uuid.UUID(maybe_uuid)
            if maybe_name:
                return maybe_name
        except ValueError:
            pass

    # Backward-compatible format: "<uuid>-<original_name>"
    if len(leaf) > 37 and leaf[36] == "-":
        maybe_uuid = leaf[:36]
        try:
            uuid.UUID(maybe_uuid)
            return leaf[37:]
        except ValueError:
            pass

    return leaf


@router.post("/storage/ensure-bucket")
def ensure_bucket(
    _: int = Depends(get_current_user_id),
):
    s3 = build_s3_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)
    return {"bucket": settings.s3_bucket, "status": "ok"}


@router.post("/upload-init", response_model=UploadInitResponse)
def upload_init(
    payload: UploadInitRequest,
    user_id: int = Depends(get_current_user_id),
):
    if payload.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")

    s3 = build_s3_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)
    s3_presign = build_s3_presign_client()

    object_key = build_object_key(
        user_id=user_id,
        trip_id=payload.trip_id,
        original_file_name=payload.file_name,
    )
    try:
        upload_url = s3_presign.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": object_key,
                "ContentType": payload.content_type,
            },
            ExpiresIn=URL_TTL_SECONDS,
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate upload URL: {e}")

    return UploadInitResponse(
        object_key=object_key,
        upload_url=_rewrite_presigned_url(upload_url),
        expires_in=URL_TTL_SECONDS,
    )


@router.get("/trips/{trip_id}", response_model=list[DocumentItemOut])
def list_trip_documents(
    trip_id: int,
    user_id: int = Depends(get_current_user_id),
):
    s3 = build_s3_client()
    ensure_bucket_exists(s3)
    prefix = f"users/{user_id}/trips/{trip_id}/"
    response = s3.list_objects_v2(Bucket=settings.s3_bucket, Prefix=prefix)
    objects = response.get("Contents", [])

    return [
        DocumentItemOut(
            object_key=item["Key"],
            file_name=_extract_visible_file_name(item["Key"]),
            size_bytes=int(item.get("Size", 0)),
            last_modified=item.get("LastModified"),
        )
        for item in objects
    ]


@router.delete("/object")
def delete_object(
    object_key: str,
    user_id: int = Depends(get_current_user_id),
):
    prefix = f"users/{user_id}/"
    if not object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    s3 = build_s3_client()
    s3.delete_object(Bucket=settings.s3_bucket, Key=object_key)
    return {"status": "ok"}


@router.post("/download-url", response_model=DownloadUrlResponse)
def download_url(
    payload: DownloadUrlRequest,
    user_id: int = Depends(get_current_user_id),
):
    # Security baseline: user can download only objects within own namespace.
    prefix = f"users/{user_id}/"
    if not payload.object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    s3 = build_s3_presign_client()
    visible_name = _extract_visible_file_name(payload.object_key)
    try:
        download_url_value = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": payload.object_key,
                # Suggest original filename in browser download dialog.
                "ResponseContentDisposition": f"inline; filename*=UTF-8''{quote(visible_name)}",
            },
            ExpiresIn=URL_TTL_SECONDS,
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate download URL: {e}")

    return DownloadUrlResponse(
        download_url=_rewrite_presigned_url(download_url_value),
        expires_in=URL_TTL_SECONDS,
    )
