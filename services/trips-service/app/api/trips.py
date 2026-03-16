import json
import urllib.error
import urllib.parse
import urllib.request
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.db.deps import get_db
from app.models.expense import Expense
from app.models.stage import Stage
from app.models.trip import Trip
from app.schemas.expense import ExpenseCreate, ExpenseOut, ExpenseUpdate
from app.schemas.stage import (
    StageCreate,
    StageOut,
    StageReorderRequest,
    StageSuggestionOut,
    StageUpdate,
)
from app.schemas.trip import TripCreate, TripOut

router = APIRouter(prefix="/trips", tags=["trips"])

STAGE_SUBTYPES: dict[str, set[str]] = {
    "transport": {
        "airplane",
        "train",
        "car",
        "bus",
        "public_transport",
        "walk",
        "taxi",
        "bicycle",
    },
    "place": {"attraction", "excursion", "museum", "park", "event", "nature"},
    "stay": {"hotel", "hostel", "apartment", "overnight", "rest"},
    "food": {"restaurant", "cafe", "fastfood", "breakfast", "lunch", "dinner", "to_go"},
    "shopping": {"mall", "market", "souvenirs", "shopping"},
    "activity": {"sport", "entertainment", "walk", "beach"},
    "document": {"tickets", "visa", "insurance", "booking"},
}

STAGE_TYPE_TO_EXPENSE_CATEGORY: dict[str, str] = {
    "transport": "transport",
    "place": "entertainment",
    "stay": "housing",
    "food": "food",
    "shopping": "entertainment",
    "activity": "entertainment",
}


@router.get("/", response_model=list[TripOut])
def list_trips(
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    stmt = select(Trip).where(Trip.user_id == user_id).order_by(Trip.id.desc())
    return db.execute(stmt).scalars().all()


def _get_user_trip_or_404(db: Session, trip_id: int, user_id: int) -> Trip:
    trip = db.execute(
        select(Trip).where(
            Trip.id == trip_id,
            Trip.user_id == user_id,
        )
    ).scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


def _get_user_stage_or_404(db: Session, trip_id: int, stage_id: int) -> Stage:
    stage = db.execute(
        select(Stage).where(
            Stage.id == stage_id,
            Stage.trip_id == trip_id,
        )
    ).scalars().first()
    if not stage:
        raise HTTPException(status_code=404, detail="Stage not found")
    return stage


def _get_trip_expense_or_404(db: Session, trip_id: int, expense_id: int) -> Expense:
    expense = db.execute(
        select(Expense).where(
            Expense.id == expense_id,
            Expense.trip_id == trip_id,
        )
    ).scalars().first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return expense


def _validate_stage_type_and_subtype(stage_type: str, subtype: str) -> tuple[str, str]:
    normalized_type = stage_type.strip().lower()
    normalized_subtype = subtype.strip().lower()
    if normalized_type not in STAGE_SUBTYPES:
        raise HTTPException(status_code=400, detail="Invalid stage type")
    if normalized_subtype not in STAGE_SUBTYPES[normalized_type]:
        raise HTTPException(status_code=400, detail="Invalid stage subtype for selected type")
    return normalized_type, normalized_subtype


def _create_expense_from_stage_if_needed(stage: Stage, db: Session) -> None:
    if stage.cost_rub is None or stage.cost_rub <= 0:
        return

    category = STAGE_TYPE_TO_EXPENSE_CATEGORY.get(stage.stage_type)
    if not category:
        return

    expense = Expense(
        trip_id=stage.trip_id,
        description=stage.title.strip(),
        amount_rub=stage.cost_rub,
        category=category,
    )
    db.add(expense)


@router.post("/", response_model=TripOut)
def create_trip(
    trip: TripCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    if trip.end_date < trip.start_date:
        raise HTTPException(
            status_code=400,
            detail="End date cannot be earlier than start date",
        )

    new_trip = Trip(
        title=trip.title,
        description=trip.description,
        start_date=trip.start_date,
        end_date=trip.end_date,
        user_id=user_id,
    )
    db.add(new_trip)
    db.commit()
    db.refresh(new_trip)
    return new_trip


@router.get("/{trip_id}/expenses", response_model=list[ExpenseOut])
def list_expenses(
    trip_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stmt = select(Expense).where(Expense.trip_id == trip_id).order_by(Expense.id.desc())
    return db.execute(stmt).scalars().all()


@router.post("/{trip_id}/expenses", response_model=ExpenseOut, status_code=201)
def create_expense(
    trip_id: int,
    payload: ExpenseCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    allowed_categories = {"food", "housing", "transport", "entertainment", "other"}
    category = payload.category.strip().lower()
    if category not in allowed_categories:
        raise HTTPException(status_code=400, detail="Invalid expense category")

    expense = Expense(
        trip_id=trip_id,
        description=payload.description.strip(),
        amount_rub=payload.amount_rub,
        category=category,
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense


@router.patch("/{trip_id}/expenses/{expense_id}", response_model=ExpenseOut)
def update_expense(
    trip_id: int,
    expense_id: int,
    payload: ExpenseUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    expense = _get_trip_expense_or_404(db=db, trip_id=trip_id, expense_id=expense_id)

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    allowed_categories = {"food", "housing", "transport", "entertainment", "other"}

    if "description" in updates and updates["description"] is not None:
        updates["description"] = updates["description"].strip()
        if not updates["description"]:
            raise HTTPException(status_code=400, detail="Description is required")

    if "category" in updates and updates["category"] is not None:
        normalized = updates["category"].strip().lower()
        if normalized not in allowed_categories:
            raise HTTPException(status_code=400, detail="Invalid expense category")
        updates["category"] = normalized

    for field_name, value in updates.items():
        setattr(expense, field_name, value)

    db.commit()
    db.refresh(expense)
    return expense


@router.delete("/{trip_id}/expenses/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_expense(
    trip_id: int,
    expense_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    expense = _get_trip_expense_or_404(db=db, trip_id=trip_id, expense_id=expense_id)

    db.delete(expense)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{trip_id}/stages", response_model=list[StageOut])
def list_stages(
    trip_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stmt = select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    return db.execute(stmt).scalars().all()


@router.post("/{trip_id}/stages", response_model=StageOut, status_code=201)
def create_stage(
    trip_id: int,
    payload: StageCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    max_position = db.execute(
        select(Stage.position).where(Stage.trip_id == trip_id).order_by(Stage.position.desc())
    ).scalars().first()
    next_position = (max_position + 1) if max_position is not None else 0

    normalized_type, normalized_subtype = _validate_stage_type_and_subtype(
        payload.stage_type,
        payload.subtype,
    )

    stage = Stage(
        trip_id=trip_id,
        position=next_position,
        stage_type=normalized_type,
        subtype=normalized_subtype,
        title=payload.title.strip(),
        start_location=payload.start_location,
        end_location=payload.end_location,
        address=payload.address,
        latitude=payload.latitude,
        longitude=payload.longitude,
        start_time=payload.start_time,
        end_time=payload.end_time,
        duration_minutes=payload.duration_minutes,
        cost_rub=payload.cost_rub,
        reference_number=payload.reference_number,
        website_url=payload.website_url,
        rating=payload.rating,
        notes=payload.notes,
        document_key=payload.document_key,
    )
    db.add(stage)
    _create_expense_from_stage_if_needed(stage=stage, db=db)
    db.commit()
    db.refresh(stage)
    return stage


@router.patch("/{trip_id}/stages/{stage_id}", response_model=StageOut)
def update_stage(
    trip_id: int,
    stage_id: int,
    payload: StageUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    updates = payload.model_dump(exclude_unset=True)

    stage_type = (
        updates.get("stage_type", stage.stage_type)
        if updates.get("stage_type", None) is not None
        else stage.stage_type
    )
    subtype = (
        updates.get("subtype", stage.subtype)
        if updates.get("subtype", None) is not None
        else stage.subtype
    )
    normalized_type, normalized_subtype = _validate_stage_type_and_subtype(stage_type, subtype)
    updates["stage_type"] = normalized_type
    updates["subtype"] = normalized_subtype

    for field_name, value in updates.items():
        if field_name == "title" and isinstance(value, str):
            value = value.strip()
        setattr(stage, field_name, value)

    db.commit()
    db.refresh(stage)
    return stage


@router.delete("/{trip_id}/stages/{stage_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_stage(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    deleted_position = stage.position
    db.delete(stage)
    db.flush()

    stages_after = db.execute(
        select(Stage).where(Stage.trip_id == trip_id, Stage.position > deleted_position).order_by(Stage.position.asc())
    ).scalars().all()
    for item in stages_after:
        item.position -= 1

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{trip_id}/stages/{stage_id}/copy", response_model=StageOut, status_code=201)
def copy_stage(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    max_position = db.execute(
        select(Stage.position).where(Stage.trip_id == trip_id).order_by(Stage.position.desc())
    ).scalars().first()
    next_position = (max_position + 1) if max_position is not None else 0

    copied = Stage(
        trip_id=stage.trip_id,
        position=next_position,
        stage_type=stage.stage_type,
        subtype=stage.subtype,
        title=f"{stage.title} (copy)",
        start_location=stage.start_location,
        end_location=stage.end_location,
        address=stage.address,
        latitude=stage.latitude,
        longitude=stage.longitude,
        start_time=stage.start_time,
        end_time=stage.end_time,
        duration_minutes=stage.duration_minutes,
        cost_rub=stage.cost_rub,
        reference_number=stage.reference_number,
        website_url=stage.website_url,
        rating=stage.rating,
        notes=stage.notes,
        document_key=stage.document_key,
    )
    db.add(copied)
    db.commit()
    db.refresh(copied)
    return copied


@router.post("/{trip_id}/stages/reorder", response_model=list[StageOut])
def reorder_stages(
    trip_id: int,
    payload: StageReorderRequest,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    current = db.execute(
        select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    ).scalars().all()
    if not current:
        return []

    by_id = {item.id: item for item in current}
    ordered_ids = [stage_id for stage_id in payload.stage_ids if stage_id in by_id]
    tail = [item.id for item in current if item.id not in set(ordered_ids)]
    final_order = ordered_ids + tail

    for index, stage_id in enumerate(final_order):
        by_id[stage_id].position = index

    db.commit()
    return db.execute(
        select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    ).scalars().all()


def _fetch_recommendations_for_stage(stage: Stage) -> list[dict]:
    query_params = {
        "stage_type": stage.stage_type,
        "subtype": stage.subtype,
    }
    if stage.end_location:
        query_params["location"] = stage.end_location
    elif stage.start_location:
        query_params["location"] = stage.start_location
    elif stage.address:
        query_params["location"] = stage.address

    if stage.latitude is not None and stage.longitude is not None:
        query_params["latitude"] = str(stage.latitude)
        query_params["longitude"] = str(stage.longitude)

    query = urllib.parse.urlencode(query_params)
    base_url = settings.recommendations_service_url.rstrip("/")
    endpoint = f"{base_url}/recommendations/suggestions?{query}"
    request = urllib.request.Request(endpoint, method="GET")

    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (TimeoutError, urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
        return []

    items = payload.get("items")
    if not isinstance(items, list):
        return []
    return [item for item in items if isinstance(item, dict)]


@router.get(
    "/{trip_id}/stages/{stage_id}/suggestions",
    response_model=list[StageSuggestionOut],
)
def list_stage_suggestions(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    items = _fetch_recommendations_for_stage(stage)
    valid: list[StageSuggestionOut] = []
    for item in items:
        try:
            suggestion = StageSuggestionOut.model_validate(item)
        except Exception:
            continue

        if suggestion.stage_type in STAGE_SUBTYPES and suggestion.subtype in STAGE_SUBTYPES[suggestion.stage_type]:
            valid.append(suggestion)
    return valid
