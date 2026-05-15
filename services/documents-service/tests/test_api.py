from __future__ import annotations

import io
import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("DATABASE_URL", "sqlite:///./test_documents_service.db")
os.environ.setdefault("JWT_SECRET", "test_secret")
os.environ.setdefault("JWT_ALG", "HS256")

from app.api import documents as documents_api
from app.main import app
from app.models.document import Document
from app.db.base import Base


engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

_current_user_id = 101
_blob_store: dict[str, bytes] = {}


def _override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def _override_get_current_user_id() -> int:
    return _current_user_id


def _fake_put_to_storage(*, object_key: str, payload: bytes, content_type: str) -> None:
    del content_type
    _blob_store[object_key] = payload


def _fake_get_from_storage(*, object_key: str) -> bytes:
    return _blob_store[object_key]


def _fake_delete_from_storage(*, object_key: str) -> None:
    _blob_store.pop(object_key, None)


app.dependency_overrides[documents_api.get_db] = _override_get_db
app.dependency_overrides[documents_api.get_current_user_id] = _override_get_current_user_id
client = TestClient(app)


def _clear_db() -> None:
    _blob_store.clear()
    with TestingSessionLocal() as db:
        db.query(Document).delete()
        db.commit()


@pytest.fixture(autouse=True)
def _patch_storage(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(documents_api, "_put_to_storage", _fake_put_to_storage)
    monkeypatch.setattr(documents_api, "_get_from_storage", _fake_get_from_storage)
    monkeypatch.setattr(documents_api, "_delete_from_storage", _fake_delete_from_storage)
    yield


def test_documents_upload_access_and_delete() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    upload = client.post(
        "/documents/upload-direct",
        files={"file": ("ticket.pdf", io.BytesIO(b"%PDF-1.4 test"), "application/pdf")},
        data={"trip_id": "1", "file_name": "ticket.pdf"},
    )
    assert upload.status_code == 200
    object_key = upload.json()["document"]["object_key"]

    list_for_trip = client.get("/documents/trips/1")
    assert list_for_trip.status_code == 200
    assert any(item.get("object_key") == object_key for item in list_for_trip.json())

    download_url = client.post("/documents/download-url", json={"object_key": object_key})
    assert download_url.status_code == 200
    assert "/documents/content?object_key=" in download_url.json()["download_url"]

    content = client.get("/documents/content", params={"object_key": object_key})
    assert content.status_code == 200
    assert content.content.startswith(b"%PDF")

    delete = client.delete("/documents/object", params={"object_key": object_key})
    assert delete.status_code == 200
    assert client.get("/documents/trips/1").json() == [
        {
            "object_key": "__shared_documents_folder__",
            "file_name": "Общие документы",
            "size_bytes": 0,
            "last_modified": None,
            "item_type": "folder",
            "is_shared": True,
            "shared_count": 0,
        }
    ]


def test_documents_permissions_and_shared_restrictions() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    own_doc = client.post(
        "/documents/upload-direct",
        files={"file": ("photo.jpg", io.BytesIO(b"\xff\xd8\xff\xe0abc"), "image/jpeg")},
        data={"trip_id": "2", "file_name": "photo.jpg"},
    ).json()["document"]["object_key"]

    shared_doc = client.post(
        "/documents/shared/upload-direct",
        files={"file": ("shared.png", io.BytesIO(b"\x89PNG\r\n\x1a\nabcd"), "image/png")},
        data={"file_name": "shared.png"},
    ).json()["document"]["object_key"]

    _current_user_id = 202
    denied = client.post("/documents/download-url", json={"object_key": own_doc})
    assert denied.status_code == 404

    _current_user_id = 101
    shared_rename_through_trip_endpoint = client.patch(
        "/documents/object/rename",
        json={"object_key": shared_doc, "file_name": "new.png"},
    )
    assert shared_rename_through_trip_endpoint.status_code == 403

    shared_rename = client.patch(
        "/documents/shared/object/rename",
        json={"object_key": shared_doc, "file_name": "renamed.png"},
    )
    assert shared_rename.status_code == 200
    assert shared_rename.json()["file_name"] == "renamed.png"


def test_documents_key_api_errors() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    unsupported_type = client.post(
        "/documents/upload-direct",
        files={"file": ("data.txt", io.BytesIO(b"hello"), "text/plain")},
        data={"trip_id": "1", "file_name": "data.txt"},
    )
    assert unsupported_type.status_code == 400

    invalid_signature = client.post(
        "/documents/upload-direct",
        files={"file": ("bad.pdf", io.BytesIO(b"NOT_A_PDF"), "application/pdf")},
        data={"trip_id": "1", "file_name": "bad.pdf"},
    )
    assert invalid_signature.status_code == 400
