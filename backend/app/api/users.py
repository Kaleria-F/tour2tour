from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import delete, select

from app.db.deps import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.user_preferences import UserPreference
from app.schemas.preferences import PreferencesUpsert, PreferencesOut

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me/preferences", response_model=PreferencesOut)
def get_preferences(
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    rows = db.execute(
        select(UserPreference).where(
            UserPreference.user_id == me.id,
            UserPreference.key == "interest",
        )
    ).scalars().all()
    return PreferencesOut(interests=[r.value for r in rows])


@router.post("/me/preferences", response_model=PreferencesOut)
def set_preferences(
    payload: PreferencesUpsert,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    db.execute(
        delete(UserPreference).where(
            UserPreference.user_id == me.id,
            UserPreference.key == "interest",
        )
    )

    for v in payload.interests:
        db.add(UserPreference(user_id=me.id, key="interest", value=v))

    db.commit()
    return PreferencesOut(interests=payload.interests)
