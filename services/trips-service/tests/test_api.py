from __future__ import annotations

import os
import sys
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("DATABASE_URL", "sqlite:///./test_trips_service.db")
os.environ.setdefault("JWT_SECRET", "test_secret")
os.environ.setdefault("JWT_ALG", "HS256")

from app.api import trips as trips_api
from app.main import app
from app.models.expense import Expense
from app.models.stage import Stage
from app.models.trip import Trip
from app.db.base import Base


engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

_current_user_id = 101


def _override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def _override_get_current_user_id() -> int:
    return _current_user_id


app.dependency_overrides[trips_api.get_db] = _override_get_db
app.dependency_overrides[trips_api.get_current_user_id] = _override_get_current_user_id
client = TestClient(app)


def _clear_db() -> None:
    with TestingSessionLocal() as db:
        db.query(Expense).delete()
        db.query(Stage).delete()
        db.query(Trip).delete()
        db.commit()


def test_trips_crud_flow() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    created = client.post(
        "/trips/",
        json={
            "title": "Moscow Weekend",
            "description": "Short trip",
            "destination_city": "Moscow",
            "start_date": "2026-06-01",
            "end_date": "2026-06-03",
            "planned_days": None,
            "card_color": "#D7E37A",
            "card_background": "orbit",
            "card_icon": "luggage",
        },
    )
    assert created.status_code == 200
    trip_id = created.json()["id"]

    listed = client.get("/trips/")
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == trip_id

    updated = client.patch(
        f"/trips/{trip_id}",
        json={"title": "Moscow Weekend Updated", "is_archived": True},
    )
    assert updated.status_code == 200
    assert updated.json()["title"] == "Moscow Weekend Updated"
    assert updated.json()["is_archived"] is True

    deleted = client.delete(f"/trips/{trip_id}")
    assert deleted.status_code == 204
    assert client.get("/trips/").json() == []


def test_stages_and_expenses_crud_and_sync() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    trip = client.post(
        "/trips/",
        json={
            "title": "Sochi",
            "start_date": "2026-07-10",
            "end_date": "2026-07-12",
        },
    ).json()
    trip_id = trip["id"]

    stage_resp = client.post(
        f"/trips/{trip_id}/stages",
        json={
            "stage_type": "transport",
            "subtype": "taxi",
            "title": "Airport taxi",
            "cost_rub": "990.00",
        },
    )
    assert stage_resp.status_code == 201
    stage_id = stage_resp.json()["id"]

    expenses = client.get(f"/trips/{trip_id}/expenses")
    assert expenses.status_code == 200
    assert len(expenses.json()) == 1
    assert expenses.json()[0]["amount_rub"] == "990.00"

    patch_stage = client.patch(
        f"/trips/{trip_id}/stages/{stage_id}",
        json={"cost_rub": "1200.00", "title": "Airport transfer"},
    )
    assert patch_stage.status_code == 200

    expenses_after_update = client.get(f"/trips/{trip_id}/expenses").json()
    assert len(expenses_after_update) == 1
    assert expenses_after_update[0]["amount_rub"] == "1200.00"
    assert expenses_after_update[0]["description"] == "Airport transfer"

    delete_stage = client.delete(f"/trips/{trip_id}/stages/{stage_id}")
    assert delete_stage.status_code == 204
    assert client.get(f"/trips/{trip_id}/expenses").json() == []


def test_permissions_and_key_errors() -> None:
    _clear_db()
    global _current_user_id
    _current_user_id = 101

    bad_trip = client.post(
        "/trips/",
        json={
            "title": "Invalid dates",
            "start_date": "2026-08-05",
            "end_date": "2026-08-01",
        },
    )
    assert bad_trip.status_code == 400

    trip_id = client.post(
        "/trips/",
        json={
            "title": "Kazan",
            "start_date": "2026-08-10",
            "end_date": "2026-08-15",
        },
    ).json()["id"]

    bad_expense = client.post(
        f"/trips/{trip_id}/expenses",
        json={"description": "X", "amount_rub": "100.00", "category": "invalid"},
    )
    assert bad_expense.status_code == 400

    trim_needs_confirm = client.patch(
        f"/trips/{trip_id}",
        json={"start_date": "2026-08-10", "end_date": "2026-08-11"},
    )
    assert trim_needs_confirm.status_code == 409

    _current_user_id = 202
    forbidden = client.get(f"/trips/{trip_id}/stages")
    assert forbidden.status_code == 404
