import json
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import delete, select

from app.db.deps import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.user_preferences import UserPreference
from app.schemas.preferences import (
    PreferencesOut,
    PreferencesUpsert,
    SurveyProfileIn,
    SurveyProfileOut,
)
from app.schemas.user import UserMeOut

router = APIRouter(prefix="/users", tags=["users"])

SURVEY_PROFILE_META_KEY = "survey_profile_meta"
INTEREST_KEY = "interest"
TRIP_FORMAT_KEY = "trip_format"
INTEREST_WEIGHT_PREFIX = "interest_weight:"


@router.get("/me", response_model=UserMeOut)
def get_me(me: User = Depends(get_current_user)):
    return UserMeOut(
        id=me.id,
        email=me.email,
        phone=me.phone,
        role=me.role,
        is_2fa_enabled=me.is_2fa_enabled,
        totp_enabled=me.totp_enabled,
        passkey_enabled=me.passkey_enabled,
    )


@router.get("/me/preferences", response_model=PreferencesOut)
def get_preferences(
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    rows = db.execute(
        select(UserPreference).where(
            UserPreference.user_id == me.id,
            UserPreference.key == INTEREST_KEY,
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
            UserPreference.key == INTEREST_KEY,
        )
    )

    for v in payload.interests:
        db.add(UserPreference(user_id=me.id, key=INTEREST_KEY, value=v))

    db.commit()
    return PreferencesOut(interests=payload.interests)


def _survey_has_completed(
    interests: list[str],
    trip_formats: list[str],
    budget: str | None,
    travel_mode: str | None,
    pace: str | None,
    interest_weights: dict[str, int],
    skipped: bool,
) -> bool:
    if skipped:
        return False
    return any(
        [
            bool(interests),
            bool(trip_formats),
            bool(budget),
            bool(travel_mode),
            bool(pace),
            bool(interest_weights),
        ]
    )


@router.get("/me/survey-profile", response_model=SurveyProfileOut)
def get_survey_profile(
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    rows = db.execute(
        select(UserPreference).where(UserPreference.user_id == me.id)
    ).scalars().all()

    interests: list[str] = []
    trip_formats: list[str] = []
    interest_weights: dict[str, int] = {}
    budget: str | None = None
    travel_mode: str | None = None
    pace: str | None = None
    skipped = False

    for row in rows:
        if row.key == INTEREST_KEY:
            interests.append(row.value)
        elif row.key == TRIP_FORMAT_KEY:
            trip_formats.append(row.value)
        elif row.key.startswith(INTEREST_WEIGHT_PREFIX):
            tag = row.key[len(INTEREST_WEIGHT_PREFIX) :]
            try:
                weight = int(row.value)
            except ValueError:
                continue
            if 1 <= weight <= 5:
                interest_weights[tag] = weight
        elif row.key == SURVEY_PROFILE_META_KEY:
            try:
                meta = json.loads(row.value)
            except json.JSONDecodeError:
                continue
            budget = meta.get("budget") if isinstance(meta.get("budget"), str) else budget
            travel_mode = (
                meta.get("travel_mode") if isinstance(meta.get("travel_mode"), str) else travel_mode
            )
            pace = meta.get("pace") if isinstance(meta.get("pace"), str) else pace
            skipped = bool(meta.get("skipped", skipped))

    has_completed = _survey_has_completed(
        interests=interests,
        trip_formats=trip_formats,
        budget=budget,
        travel_mode=travel_mode,
        pace=pace,
        interest_weights=interest_weights,
        skipped=skipped,
    )

    return SurveyProfileOut(
        interests=interests,
        trip_formats=trip_formats,
        budget=budget,
        travel_mode=travel_mode,
        pace=pace,
        interest_weights=interest_weights,
        skipped=skipped,
        has_completed=has_completed,
    )


@router.post("/me/survey-profile", response_model=SurveyProfileOut)
def set_survey_profile(
    payload: SurveyProfileIn,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    db.execute(
        delete(UserPreference).where(
            UserPreference.user_id == me.id,
            (UserPreference.key == INTEREST_KEY)
            | (UserPreference.key == TRIP_FORMAT_KEY)
            | (UserPreference.key == SURVEY_PROFILE_META_KEY)
            | (UserPreference.key.like(f"{INTEREST_WEIGHT_PREFIX}%")),
        )
    )

    for v in payload.interests:
        db.add(UserPreference(user_id=me.id, key=INTEREST_KEY, value=v))

    for v in payload.trip_formats:
        db.add(UserPreference(user_id=me.id, key=TRIP_FORMAT_KEY, value=v))

    for tag, weight in payload.interest_weights.items():
        if not (1 <= weight <= 5):
            continue
        if not tag:
            continue
        db.add(
            UserPreference(
                user_id=me.id,
                key=f"{INTEREST_WEIGHT_PREFIX}{tag}",
                value=str(weight),
            )
        )

    meta = json.dumps(
        {
            "budget": payload.budget,
            "travel_mode": payload.travel_mode,
            "pace": payload.pace,
            "skipped": payload.skipped,
        },
        ensure_ascii=True,
    )
    db.add(UserPreference(user_id=me.id, key=SURVEY_PROFILE_META_KEY, value=meta))
    db.commit()

    has_completed = _survey_has_completed(
        interests=payload.interests,
        trip_formats=payload.trip_formats,
        budget=payload.budget,
        travel_mode=payload.travel_mode,
        pace=payload.pace,
        interest_weights=payload.interest_weights,
        skipped=payload.skipped,
    )
    return SurveyProfileOut(
        interests=payload.interests,
        trip_formats=payload.trip_formats,
        budget=payload.budget,
        travel_mode=payload.travel_mode,
        pace=payload.pace,
        interest_weights=payload.interest_weights,
        skipped=payload.skipped,
        has_completed=has_completed,
    )
