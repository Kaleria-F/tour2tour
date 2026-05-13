import logging
import uuid
from urllib.request import Request, urlopen
from urllib.parse import quote, urlparse, urlunparse

from botocore.exceptions import ClientError
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.document import Document
from app.schemas.document import (
    DocumentItemOut,
    DownloadUrlRequest,
    DownloadUrlResponse,
    UploadCompleteRequest,
    UploadCompleteResponse,
    UploadInitRequest,
    UploadInitResponse,
)
from app.storage.s3_client import (
    ensure_bucket_cors,
    ensure_bucket_exists,
    get_object_storage_client,
    get_object_storage_client_with_style,
    get_presign_client,
    make_object_key,
)

router = APIRouter(prefix="/documents", tags=["documents"])
logger = logging.getLogger("documents-service")

SUPPORTED_CONTENT_TYPES = {
    "application/pdf",
    "image/png",
    "image/jpeg",
}

SUPPORTED_EXTENSIONS = {
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
}


# keeps signature valid when public endpoint host must be used in browser
# with path-style URLs

def _rewrite_presigned_url(raw_url: str) -> str:
    if not settings.s3_public_endpoint:
        return raw_url
    if not settings.s3_force_path_style:
        return raw_url

    src = urlparse(raw_url)
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


def _sanitize_file_name(file_name: str) -> str:
    cleaned = file_name.replace("\\", "_").replace("/", "_").strip()
    if not cleaned:
        raise HTTPException(status_code=400, detail="Invalid file name")

    dot_idx = cleaned.rfind(".")
    extension = cleaned[dot_idx:].lower() if dot_idx >= 0 else ""
    if extension not in SUPPORTED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported file extension")
    return cleaned


def _detect_magic(content_type: str, first_bytes: bytes) -> bool:
    if content_type == "application/pdf":
        return first_bytes.startswith(b"%PDF")
    if content_type == "image/png":
        return first_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    if content_type == "image/jpeg":
        return first_bytes.startswith(b"\xff\xd8")
    return False


def _file_name_from_object_key(object_key: str) -> str:
    leaf = object_key.split("/")[-1]
    if "__" in leaf:
        maybe_uuid, maybe_name = leaf.split("__", 1)
        try:
            uuid.UUID(maybe_uuid)
            if maybe_name:
                return maybe_name
        except ValueError:
            pass
    if len(leaf) > 37 and leaf[36] == "-":
        maybe_uuid = leaf[:36]
        try:
            uuid.UUID(maybe_uuid)
            return leaf[37:]
        except ValueError:
            pass
    return leaf


def _get_document_or_404(db: Session, user_id: int, object_key: str) -> Document:
    doc = db.scalar(
        select(Document).where(
            Document.user_id == user_id,
            Document.object_key == object_key,
        )
    )
    if doc is None:
        raise HTTPException(status_code=404, detail="Document not found")
    return doc


def _upsert_document(
    db: Session,
    *,
    user_id: int,
    trip_id: int,
    object_key: str,
    file_name: str,
    content_type: str,
    size_bytes: int,
) -> Document:
    existing = db.scalar(select(Document).where(Document.object_key == object_key))
    if existing:
        return existing

    row = Document(
        user_id=user_id,
        trip_id=trip_id,
        object_key=object_key,
        file_name=file_name,
        content_type=content_type,
        size_bytes=size_bytes,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _upload_via_presigned_put(*, object_key: str, payload: bytes, content_type: str) -> None:
    presign_client = get_presign_client()
    upload_url = presign_client.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": settings.s3_bucket,
            "Key": object_key,
        },
        ExpiresIn=settings.s3_presign_ttl_seconds,
    )
    rewritten_url = _rewrite_presigned_url(upload_url)
    req = Request(
        rewritten_url,
        data=payload,
        method="PUT",
        headers={
            "Content-Type": content_type,
        },
    )
    with urlopen(req, timeout=30) as response:
        status = getattr(response, "status", 0) or 0
        if status not in (200, 201, 204):
            raise HTTPException(status_code=500, detail=f"Presigned upload failed with status {status}")


@router.post("/storage/ensure-bucket")
def ensure_bucket(_: int = Depends(get_current_user_id)):
    s3 = get_object_storage_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)

    try:
        s3.put_public_access_block(
            Bucket=settings.s3_bucket,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": False,
                "IgnorePublicAcls": False,
                "BlockPublicPolicy": False,
                "RestrictPublicBuckets": False,
            },
        )
    except ClientError:
        pass

    return {"status": "ok", "bucket": settings.s3_bucket}


@router.post("/upload-init", response_model=UploadInitResponse)
def upload_init(payload: UploadInitRequest, user_id: int = Depends(get_current_user_id)):
    content_type = payload.content_type.lower().strip()
    if content_type not in SUPPORTED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")
    if payload.file_size_bytes > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="File too large")

    file_name = _sanitize_file_name(payload.file_name)
    object_key = make_object_key(user_id=user_id, trip_id=payload.trip_id, file_name=file_name)

    try:
        upload_url = get_presign_client().generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": object_key,
            },
            ExpiresIn=settings.s3_presign_ttl_seconds,
        )
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate upload URL: {exc}")

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
    expected_prefix = f"users/{user_id}/trips/{payload.trip_id}/"
    if not payload.object_key.startswith(expected_prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    s3 = get_object_storage_client()
    try:
        meta = s3.head_object(Bucket=settings.s3_bucket, Key=payload.object_key)
    except ClientError:
        raise HTTPException(status_code=400, detail="Uploaded object not found")

    content_type = (meta.get("ContentType") or "").lower()
    size_bytes = int(meta.get("ContentLength") or 0)

    if content_type not in SUPPORTED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")
    if size_bytes <= 0 or size_bytes > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="Invalid file size")

    try:
        first_chunk = s3.get_object(Bucket=settings.s3_bucket, Key=payload.object_key, Range="bytes=0-15")
        signature = first_chunk["Body"].read()
    except ClientError:
        signature = b""

    if not _detect_magic(content_type, signature):
        raise HTTPException(status_code=400, detail="File signature validation failed")

    doc = _upsert_document(
        db,
        user_id=user_id,
        trip_id=payload.trip_id,
        object_key=payload.object_key,
        file_name=_file_name_from_object_key(payload.object_key),
        content_type=content_type,
        size_bytes=size_bytes,
    )

    if settings.enable_upload_scan:
        logger.warning("AV scan enabled but integration is not configured yet")

    return UploadCompleteResponse(
        status="ok",
        document=DocumentItemOut(
            object_key=doc.object_key,
            file_name=doc.file_name,
            size_bytes=doc.size_bytes,
            last_modified=doc.created_at,
        ),
    )


@router.post("/upload-direct", response_model=UploadCompleteResponse)
async def upload_direct(
    trip_id: int = Form(...),
    file_name: str = Form(...),
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    cleaned_name = _sanitize_file_name(file_name)
    content_type = (file.content_type or "").lower().strip()
    if content_type not in SUPPORTED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")

    payload = await file.read()
    size_bytes = len(payload)
    if size_bytes <= 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if size_bytes > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="File too large")
    if not _detect_magic(content_type, payload[:16]):
        raise HTTPException(status_code=400, detail="File signature validation failed")

    s3 = get_object_storage_client()
    ensure_bucket_exists(s3)
    ensure_bucket_cors(s3)

    object_key = make_object_key(user_id=user_id, trip_id=trip_id, file_name=cleaned_name)

    put_kwargs = {
        "Bucket": settings.s3_bucket,
        "Key": object_key,
        "Body": payload,
        "ContentType": content_type,
    }
    if settings.s3_sse_mode:
        put_kwargs["ServerSideEncryption"] = settings.s3_sse_mode

    def _put(client, kwargs: dict, label: str) -> tuple[bool, str | None]:
        try:
            client.put_object(**kwargs)
            logger.info("S3 put_object succeeded via %s", label)
            return True, None
        except ClientError as err:
            code_local = (err.response.get("Error") or {}).get("Code") or "Unknown"
            msg_local = (err.response.get("Error") or {}).get("Message") or ""
            logger.warning("S3 put_object failed via %s code=%s message=%s", label, code_local, msg_local)
            return False, code_local

    ok, code = _put(s3, put_kwargs, "primary")
    if not ok and "ServerSideEncryption" in put_kwargs:
        # Retry with same style but without SSE for providers that deny this header.
        no_sse_kwargs = dict(put_kwargs)
        no_sse_kwargs.pop("ServerSideEncryption", None)
        ok, code = _put(s3, no_sse_kwargs, "primary-no-sse")

    if not ok and code in {"AccessDenied", "Unauthorized", "SignatureDoesNotMatch"}:
        # Retry with the opposite addressing style to rule out style-related
        # provider quirks (path vs virtual host).
        alt_style = "virtual" if settings.s3_force_path_style else "path"
        alt_client = get_object_storage_client_with_style(alt_style)
        alt_kwargs = dict(put_kwargs)
        alt_kwargs.pop("ServerSideEncryption", None)
        ok, code = _put(alt_client, alt_kwargs, f"alt-style-{alt_style}")

    if not ok:
        if code in {"AccessDenied", "Unauthorized", "SignatureDoesNotMatch"}:
            # Final fallback: upload server-to-S3 via presigned URL.
            # This avoids browser CORS and also covers providers that reject
            # header-auth PutObject but accept query-signed PUT.
            try:
                _upload_via_presigned_put(
                    object_key=object_key,
                    payload=payload,
                    content_type=content_type,
                )
                ok = True
            except Exception as exc:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        f"S3 upload forbidden ({code}); "
                        f"bucket={settings.s3_bucket}; endpoint={settings.s3_endpoint}; "
                        f"region={settings.s3_region}; force_path_style={settings.s3_force_path_style}; "
                        f"presigned_fallback_error={type(exc).__name__}"
                    ),
                )
        if ok:
            code = None
        elif code in {"NoSuchBucket", "NotFound"}:
            raise HTTPException(status_code=400, detail=f"S3 bucket not found ({settings.s3_bucket})")
        elif code:
            raise HTTPException(status_code=500, detail=f"S3 upload failed ({code or 'Unknown'})")

    doc = _upsert_document(
        db,
        user_id=user_id,
        trip_id=trip_id,
        object_key=object_key,
        file_name=cleaned_name,
        content_type=content_type,
        size_bytes=size_bytes,
    )

    return UploadCompleteResponse(
        status="ok",
        document=DocumentItemOut(
            object_key=doc.object_key,
            file_name=doc.file_name,
            size_bytes=doc.size_bytes,
            last_modified=doc.created_at,
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
            object_key=row.object_key,
            file_name=row.file_name,
            size_bytes=row.size_bytes,
            last_modified=row.created_at,
        )
        for row in rows
    ]


@router.post("/download-url", response_model=DownloadUrlResponse)
def download_url(
    payload: DownloadUrlRequest,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    prefix = f"users/{user_id}/"
    if not payload.object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    _get_document_or_404(db, user_id, payload.object_key)

    visible_name = _file_name_from_object_key(payload.object_key)
    try:
        url = get_presign_client().generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": payload.object_key,
                "ResponseContentDisposition": f"inline; filename*=UTF-8''{quote(visible_name)}",
            },
            ExpiresIn=settings.s3_presign_ttl_seconds,
        )
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate download URL: {exc}")

    return DownloadUrlResponse(
        download_url=_rewrite_presigned_url(url),
        expires_in=settings.s3_presign_ttl_seconds,
    )


@router.delete("/object")
def delete_object(
    object_key: str,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    prefix = f"users/{user_id}/"
    if not object_key.startswith(prefix):
        raise HTTPException(status_code=403, detail="Forbidden")

    row = _get_document_or_404(db, user_id, object_key)

    try:
        get_object_storage_client().delete_object(Bucket=settings.s3_bucket, Key=object_key)
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=f"Failed to delete file from storage: {exc}")

    db.delete(row)
    db.commit()

    return {"status": "ok"}
