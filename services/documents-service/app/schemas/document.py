from datetime import datetime

from pydantic import BaseModel, Field


class DocumentItemOut(BaseModel):
    object_key: str
    file_name: str
    size_bytes: int
    last_modified: datetime | None = None


class UploadDirectResponse(BaseModel):
    status: str
    document: DocumentItemOut


class DownloadUrlRequest(BaseModel):
    object_key: str = Field(..., min_length=1, max_length=500)


class DownloadUrlResponse(BaseModel):
    download_url: str
    expires_in: int
