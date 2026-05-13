import io
import logging
from datetime import datetime, timezone
from urllib.parse import quote
from urllib.error import HTTPError, URLError

from botocore.exceptions import BotoCoreError, ClientError
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.document import Document
from app.schemas.document import (
    DocumentItemOut,
    DownloadUrlRequest,
    DownloadUrlResponse,
    UploadDirectResponse,
)
from app.storage.s3_client import build_object_key, get_s3_client

router = APIRouter(prefix="/documents", tags=["documents"])
logger = logging.getLogger("documents-service")

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "image/png",
    "image/jpeg",
}

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
}


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


def _to_item(doc: Document) -> DocumentItemOut:
    return DocumentItemOut(
        object_key=doc.object_key,
        file_name=doc.file_name,
        size_bytes=doc.size_bytes,
        last_modified=doc.created_at,
    )


def _ensure_owned_document(db: Session, user_id: int, object_key: str) -> Document:
    row = db.scalar(
        select(Document).where(
            Document.user_id == user_id,
            Document.object_key == object_key,
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Document not found")
    return row


def _put_to_storage(*, object_key: str, payload: bytes, content_type: str) -> None:
    put_args = {
        "Bucket": settings.s3_bucket,
        "Key": object_key,
        "Body": payload,
        "ContentType": content_type,
    }
    if settings.s3_sse_mode:
        put_args["ServerSideEncryption"] = settings.s3_sse_mode
    s3 = get_s3_client()
    try:
        s3.put_object(**put_args)
    except ClientError:
        if "ServerSideEncryption" in put_args:
            retry_args = dict(put_args)
            retry_args.pop("ServerSideEncryption", None)
            s3.put_object(**retry_args)
        else:
            raise


def _get_from_storage(*, object_key: str) -> bytes:
    response = get_s3_client().get_object(Bucket=settings.s3_bucket, Key=object_key)
    return response["Body"].read()


def _delete_from_storage(*, object_key: str) -> None:
    get_s3_client().delete_object(Bucket=settings.s3_bucket, Key=object_key)


@router.post("/upload-direct", response_model=UploadDirectResponse)
async def upload_direct(
    trip_id: int = Form(...),
    file_name: str = Form(...),
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    normalized_name = _normalize_name(file_name)
    content_type = (file.content_type or "").lower().strip()
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Unsupported content type")

    payload = await file.read()
    size = len(payload)
    if size <= 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if size > settings.max_upload_size_bytes:
        raise HTTPException(status_code=400, detail="File too large")
    if not _verify_magic(content_type, payload[:16]):
        raise HTTPException(status_code=400, detail="File signature validation failed")

    object_key = build_object_key(user_id=user_id, trip_id=trip_id, file_name=normalized_name)

    try:
        _put_to_storage(
            object_key=object_key,
            payload=payload,
            content_type=content_type,
        )
    except ClientError as exc:
        code = (exc.response.get("Error") or {}).get("Code") or "Unknown"
        raise HTTPException(status_code=403, detail=f"S3 upload forbidden ({code})")
    except (BotoCoreError, HTTPError, URLError, RuntimeError) as exc:
        logger.exception("Storage upload failed")
        raise HTTPException(status_code=500, detail="Storage upload failed")

    row = Document(
        user_id=user_id,
        trip_id=trip_id,
        object_key=object_key,
        file_name=normalized_name,
        content_type=content_type,
        size_bytes=size,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    return UploadDirectResponse(status="ok", document=_to_item(row))


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
    return [_to_item(row) for row in rows]


@router.post("/download-url", response_model=DownloadUrlResponse)
def download_url(
    payload: DownloadUrlRequest,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    _ensure_owned_document(db, user_id, payload.object_key)
    quoted = quote(payload.object_key, safe="")
    return DownloadUrlResponse(
        download_url=f"/documents/content?object_key={quoted}",
        expires_in=settings.s3_presign_ttl_seconds,
    )


@router.get("/content")
def content(
    object_key: str,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    row = _ensure_owned_document(db, user_id, object_key)

    try:
        body = _get_from_storage(object_key=row.object_key)
    except ClientError as exc:
        code = (exc.response.get("Error") or {}).get("Code") or "Unknown"
        raise HTTPException(status_code=404, detail=f"File not found in storage ({code})")
    except (BotoCoreError, HTTPError, URLError, RuntimeError) as exc:
        logger.exception("Storage read failed")
        raise HTTPException(status_code=500, detail="Storage read failed")

    headers = {
        "Content-Disposition": f"inline; filename*=UTF-8''{quote(row.file_name)}",
        "Cache-Control": "no-store",
    }
    return StreamingResponse(
        io.BytesIO(body),
        media_type=row.content_type,
        headers=headers,
    )


@router.delete("/object")
def delete_object(
    object_key: str,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    row = _ensure_owned_document(db, user_id, object_key)

    try:
        _delete_from_storage(object_key=row.object_key)
    except (ClientError, BotoCoreError, HTTPError, URLError, RuntimeError):
        # We still remove metadata to avoid broken rows and keep sync stable.
        pass

    db.delete(row)
    db.commit()
    return {"status": "ok", "deleted_at": datetime.now(timezone.utc).isoformat()}
