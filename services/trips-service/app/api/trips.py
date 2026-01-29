from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.schemas.trip import TripCreate, TripOut
from app.models.trip import Trip

router = APIRouter(prefix="/trips", tags=["trips"])


@router.post("/", response_model=TripOut)
def create_trip(
    trip: TripCreate,
    db: Session = Depends(get_db),
):
    # TODO: заменить заглушку на реальный user_id из auth-service.
    user_id = 1

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
