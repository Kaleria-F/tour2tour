import uuid
import logging
from urllib.parse import quote, urlparse, urlunparse

from fastapi import APIRouter, Depends, HTTPException
from botocore.exceptions import ClientError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.document import Document
from app.schemas.document import (
    DownloadUrlRequest,
    DownloadUrlResponse,
    DocumentItemOut,
    UploadCompleteRequest,
    UploadCompleteResponse,
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
logger = logging.getLogger("documents-service")

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
}

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".jpg",
    ".jpeg",
    ".png",
}


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


def _normalize_name(file_name: str) -> str:
    clean = file_name.replace("\\", "_").replace("/", "_").strip()
    if not clean:
        raise HTTPException(status_code=400, detail="Invalid file name")
    ext = "." + clean.split(".")[-1].lower() if "." in clean else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported file extension")
    return clean


def _verify_magic(content_type: str, first_bytes: bytes) -> bool:
    if content_type == "application/pdf":
        return first_bytes.startswith(b"%PDF")
    if content_type == "image/png":
        return first_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    if content_type == "image/jpeg":
        return first_bytes.startswith(b"\xff\xd8")
    return False


@router.post("/storage/ensure-bucket")
def ensure_bucket(
    _: int = Depends(get_current_user_id),
):
    s3 = build_s3_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)
    try:
        s3.put_public_access_block(
            Bucket=settings.s3_bucket,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            },
        )
    except ClientError:
        pass
    return {"bucket": settings.s3_bucket, "status": "ok"}


@router.post("/upload-init", response_model=UploadInitResponse)
def upload_init(
    payload: UploadInitRequest,
    user_id: int = Depends(get_current_user_id),
):
    if payload.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")
    if payload.file_size_bytes > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="File too large")
    normalized_name = _normalize_name(payload.file_name)

    s3 = build_s3_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)
    s3_presign = build_s3_presign_client()

    object_key = build_object_key(
        user_id=user_id,
        trip_id=payload.trip_id,
        original_file_name=normalized_name,
    )
    params = {
        "Bucket": settings.s3_bucket,
        "Key": object_key,
    }
    # Do not sign Content-Type into the presigned PUT request.
    # Browsers may normalize or omit this header on web uploads, which causes
    # SignatureDoesNotMatch/403 even when the file bytes are valid.
    # The uploaded object is still validated server-side in upload_complete().
    try:
        upload_url = s3_presign.generate_presigned_url(
            ClientMethod="put_object",
            Params=params,
            ExpiresIn=settings.s3_presign_ttl_seconds,
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate upload URL: {e}")

    logger.info(
        "upload_init user_id=%s trip_id=%s object_key=%s content_type=%s size=%s",
        user_id,
        payload.trip_id,
        object_key,
        payload.content_type,
        payload.file_size_bytes,
    )
    return UploadInitResponse(
        object_key=object_key,
        upload_url=_rewrite_presigned_url(upload_url),
        expires_in=settings.s3_presign_ttl_seconds,
    )


@router.post("/upload-complete", response_model=UploadCompleteResponse)
def upload_complete(
    payload: UploadCompleteRequest,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    prefix = f"users/{user_id}/trips/{payload.trip_id}/"
    if not payload.object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    s3 = build_s3_client()
    try:
        head = s3.head_object(Bucket=settings.s3_bucket, Key=payload.object_key)
    except ClientError as e:
        raise HTTPException(status_code=400, detail=f"Object is not uploaded: {e}")

    content_type = (head.get("ContentType") or "").lower()
    size = int(head.get("ContentLength") or 0)
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")
    if size <= 0 or size > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="Invalid or too large file")

    try:
        first_chunk = s3.get_object(
            Bucket=settings.s3_bucket,
            Key=payload.object_key,
            Range="bytes=0-15",
        )
        first_bytes = first_chunk["Body"].read()
    except ClientError:
        first_bytes = b""

    if not _verify_magic(content_type, first_bytes):
        raise HTTPException(status_code=400, detail="File signature validation failed")

    if settings.enable_upload_scan:
        # Placeholder: integrate ClamAV/external AV here.
        logger.warning("upload_scan_enabled_but_not_integrated object_key=%s", payload.object_key)

    existing = db.scalar(select(Document).where(Document.object_key == payload.object_key))
    if existing is None:
        existing = Document(
            user_id=user_id,
            trip_id=payload.trip_id,
            object_key=payload.object_key,
            file_name=_extract_visible_file_name(payload.object_key),
            content_type=content_type,
            size_bytes=size,
        )
        db.add(existing)
        db.commit()
        db.refresh(existing)

    logger.info(
        "upload_complete user_id=%s trip_id=%s object_key=%s content_type=%s size=%s",
        user_id,
        payload.trip_id,
        payload.object_key,
        content_type,
        size,
    )
    return UploadCompleteResponse(
        status="ok",
        document=DocumentItemOut(
            object_key=existing.object_key,
            file_name=existing.file_name,
            size_bytes=existing.size_bytes,
            last_modified=existing.created_at,
        ),
    )


@router.get("/trips/{trip_id}", response_model=list[DocumentItemOut])
def list_trip_documents(
    trip_id: int,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(Document)
        .where(Document.user_id == user_id, Document.trip_id == trip_id)
        .order_by(Document.created_at.desc())
    ).all()
    return [
        DocumentItemOut(
            object_key=item.object_key,
            file_name=item.file_name,
            size_bytes=item.size_bytes,
            last_modified=item.created_at,
        )
        for item in rows
    ]


@router.delete("/object")
def delete_object(
    object_key: str,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    prefix = f"users/{user_id}/"
    if not object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    s3 = build_s3_client()
    s3.delete_object(Bucket=settings.s3_bucket, Key=object_key)
    row = db.scalar(select(Document).where(Document.object_key == object_key, Document.user_id == user_id))
    if row is not None:
        db.delete(row)
        db.commit()
    logger.info("delete_object user_id=%s object_key=%s", user_id, object_key)
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
            ExpiresIn=settings.s3_presign_ttl_seconds,
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate download URL: {e}")

    return DownloadUrlResponse(
        download_url=_rewrite_presigned_url(download_url_value),
        expires_in=settings.s3_presign_ttl_seconds,
    )
#новая
