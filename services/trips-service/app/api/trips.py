from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id
from app.db.deps import get_db
from app.models.expense import Expense
from app.schemas.trip import TripCreate, TripOut
from app.schemas.expense import ExpenseCreate, ExpenseOut
from app.models.trip import Trip

router = APIRouter(prefix="/trips", tags=["trips"])


@router.get("/", response_model=list[TripOut])
def list_trips(
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    stmt = (
        select(Trip)
        .where(Trip.user_id == user_id)
        .order_by(Trip.id.desc())
    )
    return db.execute(stmt).scalars().all()


def _get_user_trip_or_404(db: Session, trip_id: int, user_id: int) -> Trip:
    trip = db.execute(
        select(Trip).where(
            Trip.id == trip_id,
            Trip.user_id == user_id,
        )
    ).scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Путешествие не найдено")
    return trip


@router.post("/", response_model=TripOut)
def create_trip(
    trip: TripCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    if trip.end_date < trip.start_date:
        raise HTTPException(
            status_code=400,
            detail="Дата окончания не может быть раньше даты начала",
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

    stmt = (
        select(Expense)
        .where(Expense.trip_id == trip_id)
        .order_by(Expense.id.desc())
    )
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
        raise HTTPException(status_code=400, detail="Некорректная категория расхода")

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
