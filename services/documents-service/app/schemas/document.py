from datetime import datetime

from pydantic import BaseModel, Field


class UploadInitRequest(BaseModel):
    trip_id: int = Field(..., gt=0)
    file_name: str = Field(..., min_length=1, max_length=255)
    content_type: str = Field(..., min_length=1, max_length=120)


class UploadInitResponse(BaseModel):
    object_key: str
    upload_url: str
    expires_in: int


class DownloadUrlRequest(BaseModel):
    object_key: str = Field(..., min_length=1, max_length=500)


class DownloadUrlResponse(BaseModel):
    download_url: str
    expires_in: int


class DocumentItemOut(BaseModel):
    object_key: str
    file_name: str
    size_bytes: int
    last_modified: datetime | None = None
