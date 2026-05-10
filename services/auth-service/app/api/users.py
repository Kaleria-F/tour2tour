import json
import logging
import secrets
from collections import Counter, defaultdict

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import delete, select

from app.core import auth_state
from app.core.mailer import send_email
from app.db.deps import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.user_preferences import UserPreference
from app.schemas.preferences import (
    INTEREST_TAGS,
    PACE_VALUES,
    PreferencesOut,
    PreferencesUpsert,
    SurveyProfileIn,
    SurveyProfileOut,
    TRAVEL_MODE_TAGS,
    TRIP_FORMAT_TAGS,
)
from app.schemas.user import (
    EmailChangeConfirmIn,
    EmailChangeRequestIn,
    StageAssistantTrialOut,
    UserMeOut,
    UserProfileUpdateIn,
)

router = APIRouter(prefix="/users", tags=["users"])
logger = logging.getLogger(__name__)

SURVEY_PROFILE_META_KEY = "survey_profile_meta"
INTEREST_KEY = "interest"
TRIP_FORMAT_KEY = "trip_format"
INTEREST_WEIGHT_PREFIX = "interest_weight:"
INTEREST_ALIASES = {
    "museum": "museums",
}
TRIP_FORMAT_ALIASES = {
    "weekend": "calm",
}
TRAVEL_MODE_ALIASES = {
    "walk": "walk",
}
EMAIL_CHANGE_CODE_TTL = 10 * 60
TRIP_SURVEY_PREFIX = "trip:"
STAGE_ASSISTANT_TRIAL_KEY = "stage_assistant_trial_used"
STAGE_ASSISTANT_TRIAL_LIMIT = 5


@router.get("/me", response_model=UserMeOut)
def get_me(me: User = Depends(get_current_user)):
    return UserMeOut(
        id=me.id,
        email=me.email,
        phone=me.phone,
        display_name=me.display_name,
        avatar_url=me.avatar_url,
        is_premium=me.is_premium,
        role=me.role,
        is_2fa_enabled=me.is_2fa_enabled,
        totp_enabled=me.totp_enabled,
        passkey_enabled=me.passkey_enabled,
    )


def _normalize_email(email: str | None) -> str:
    return (email or "").strip().lower()


def _read_stage_assistant_trial_used(db: Session, user_id: int) -> int:
    row = db.execute(
        select(UserPreference).where(
            UserPreference.user_id == user_id,
            UserPreference.key == STAGE_ASSISTANT_TRIAL_KEY,
        )
    ).scalars().first()
    if row is None:
        return 0
    try:
        return max(0, min(int(row.value), STAGE_ASSISTANT_TRIAL_LIMIT))
    except (TypeError, ValueError):
        return 0


def _write_stage_assistant_trial_used(db: Session, user_id: int, used: int) -> int:
    normalized = max(0, min(used, STAGE_ASSISTANT_TRIAL_LIMIT))
    row = db.execute(
        select(UserPreference).where(
            UserPreference.user_id == user_id,
            UserPreference.key == STAGE_ASSISTANT_TRIAL_KEY,
        )
    ).scalars().first()
    if row is None:
        db.add(
            UserPreference(
                user_id=user_id,
                key=STAGE_ASSISTANT_TRIAL_KEY,
                value=str(normalized),
            )
        )
    else:
        row.value = str(normalized)
        db.add(row)
    db.commit()
    return normalized


def _stage_assistant_trial_out(used: int, is_premium: bool) -> StageAssistantTrialOut:
    normalized = max(0, min(used, STAGE_ASSISTANT_TRIAL_LIMIT))
    remaining = STAGE_ASSISTANT_TRIAL_LIMIT if is_premium else max(
        0,
        STAGE_ASSISTANT_TRIAL_LIMIT - normalized,
    )
    return StageAssistantTrialOut(
        limit=STAGE_ASSISTANT_TRIAL_LIMIT,
        used=normalized,
        remaining=remaining,
        is_locked=(not is_premium and remaining <= 0),
    )


def _email_change_key(user_id: int, email: str) -> str:
    return f"users:email-change:{user_id}:{_normalize_email(email)}"


def _state_read_or_503(key: str) -> dict | None:
    try:
        return auth_state.get_json(key)
    except RuntimeError:
        logger.exception("Redis read failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _state_write_or_503(key: str, value: dict, ttl_seconds: int) -> None:
    try:
        auth_state.set_json(key, value, ttl_seconds=ttl_seconds)
    except RuntimeError:
        logger.exception("Redis write failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _state_delete_or_503(key: str) -> None:
    try:
        auth_state.delete(key)
    except RuntimeError:
        logger.exception("Redis delete failed for key %s", key)
        raise HTTPException(status_code=503, detail="Temporary auth storage is unavailable.")


def _build_code_email(code: str) -> tuple[str, str]:
    text = (
        "Tour2Tour\n\n"
        "Подтверждение новой почты\n\n"
        f"Код: {code}\n\n"
        "Код действует 10 минут. Если вы не запрашивали изменение почты, просто проигнорируйте письмо."
    )
    html = f"""
<html>
  <body style="margin:0;padding:0;background:#f4f7fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#172033;">
    <div style="max-width:560px;margin:0 auto;padding:32px 16px;">
      <div style="background:#ffffff;border-radius:20px;padding:32px 28px;border:1px solid #e6ebf2;box-shadow:0 12px 40px rgba(23,32,51,0.08);">
        <div style="font-size:13px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#4b6bfb;margin-bottom:18px;">Tour2Tour</div>
        <h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;color:#172033;">Подтверждение новой почты</h1>
        <p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#4b5567;">
          Введите этот код в приложении, чтобы подтвердить изменение email.
        </p>
        <div style="margin:0 0 22px;padding:18px 20px;background:#f7f9fc;border:1px solid #dbe4f0;border-radius:16px;text-align:center;">
          <div style="margin-bottom:8px;font-size:12px;letter-spacing:0.12em;text-transform:uppercase;color:#7b8797;">Код подтверждения</div>
          <div style="font-size:32px;line-height:1;font-weight:800;letter-spacing:0.28em;color:#172033;">{code}</div>
        </div>
        <p style="margin:0;font-size:14px;line-height:1.6;color:#4b5567;">
          Код действует 10 минут. Если вы не запрашивали изменение почты, просто проигнорируйте письмо.
        </p>
      </div>
    </div>
  </body>
</html>
""".strip()
    return text, html


def _send_email_safely(to_email: str, subject: str, body: str, html_body: str | None = None) -> None:
    try:
        send_email(to_email=to_email, subject=subject, body=body, html_body=html_body)
        logger.info("Email sent to %s", to_email)
    except Exception:
        logger.exception("Failed to send email to %s", to_email)


@router.patch("/me", response_model=UserMeOut)
def update_me(
    payload: UserProfileUpdateIn,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    if payload.phone != me.phone and payload.phone is not None:
        existing = db.execute(
            select(User).where(User.phone == payload.phone, User.id != me.id)
        ).scalars().first()
        if existing:
            raise HTTPException(status_code=409, detail="User already exists.")

    me.display_name = payload.display_name
    me.phone = payload.phone
    me.avatar_url = payload.avatar_url
    db.add(me)
    db.commit()
    db.refresh(me)
    return get_me(me)


@router.post("/me/request-email-change")
def request_email_change(
    payload: EmailChangeRequestIn,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    new_email = _normalize_email(str(payload.new_email))
    if new_email == _normalize_email(me.email):
        raise HTTPException(status_code=400, detail="New email must differ from the current one.")

    existing = db.execute(
        select(User).where(User.email == new_email, User.id != me.id)
    ).scalars().first()
    if existing:
        raise HTTPException(status_code=409, detail="User already exists.")

    code = f"{secrets.randbelow(900000) + 100000}"
    key = _email_change_key(me.id, new_email)
    _state_write_or_503(key, {"code": code, "new_email": new_email}, ttl_seconds=EMAIL_CHANGE_CODE_TTL)
    text_body, html_body = _build_code_email(code)
    _send_email_safely(
        to_email=new_email,
        subject="Tour2Tour: код подтверждения новой почты",
        body=text_body,
        html_body=html_body,
    )
    return {"status": "ok"}


@router.post("/me/confirm-email-change", response_model=UserMeOut)
def confirm_email_change(
    payload: EmailChangeConfirmIn,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    new_email = _normalize_email(str(payload.new_email))
    key = _email_change_key(me.id, new_email)
    record = _state_read_or_503(key)
    if not record or record.get("code") != payload.code:
        raise HTTPException(status_code=400, detail="Verification code is invalid or expired.")

    existing = db.execute(
        select(User).where(User.email == new_email, User.id != me.id)
    ).scalars().first()
    if existing:
        _state_delete_or_503(key)
        raise HTTPException(status_code=409, detail="User already exists.")

    me.email = new_email
    db.add(me)
    db.commit()
    db.refresh(me)
    _state_delete_or_503(key)
    return get_me(me)


@router.get("/me/stage-assistant-trial", response_model=StageAssistantTrialOut)
def get_stage_assistant_trial(
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    used = _read_stage_assistant_trial_used(db, me.id)
    return _stage_assistant_trial_out(used, me.is_premium)


@router.post("/me/stage-assistant-trial/consume", response_model=StageAssistantTrialOut)
def consume_stage_assistant_trial(
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    if me.is_premium:
        return _stage_assistant_trial_out(0, True)

    used = _read_stage_assistant_trial_used(db, me.id)
    next_used = min(STAGE_ASSISTANT_TRIAL_LIMIT, used + 1)
    stored_used = _write_stage_assistant_trial_used(db, me.id, next_used)
    return _stage_assistant_trial_out(stored_used, False)


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


def _filter_known_values(values: list[str], allowed: set[str]) -> list[str]:
    seen: set[str] = set()
    filtered: list[str] = []
    for value in values:
        if value not in allowed or value in seen:
            continue
        seen.add(value)
        filtered.append(value)
    return filtered


def _normalize_value(value: str | None, aliases: dict[str, str]) -> str | None:
    if value is None:
        return None
    normalized = aliases.get(value, value)
    return normalized.strip() or None


def _trip_scope_prefix(trip_id: int) -> str:
    return f"{TRIP_SURVEY_PREFIX}{trip_id}:"


def _trip_scoped_key(trip_id: int, key: str) -> str:
    return f"{_trip_scope_prefix(trip_id)}{key}"


def _empty_profile_state() -> dict:
    return {
        "interests": [],
        "trip_formats": [],
        "interest_weights": {},
        "budget": None,
        "travel_mode": None,
        "pace": None,
        "skipped": False,
    }


def _normalize_profile_state(state: dict) -> dict:
    interests = _filter_known_values(state["interests"], INTEREST_TAGS)
    trip_formats = _filter_known_values(state["trip_formats"], TRIP_FORMAT_TAGS)
    interest_weights = {
        tag: weight
        for tag, weight in state["interest_weights"].items()
        if tag in INTEREST_TAGS and isinstance(weight, int) and 1 <= weight <= 5
    }
    travel_mode = state["travel_mode"] if state["travel_mode"] in TRAVEL_MODE_TAGS else None
    pace = state["pace"] if state["pace"] in PACE_VALUES else None
    budget = state["budget"]
    skipped = bool(state["skipped"])
    has_completed = _survey_has_completed(
        interests=interests,
        trip_formats=trip_formats,
        budget=budget,
        travel_mode=travel_mode,
        pace=pace,
        interest_weights=interest_weights,
        skipped=skipped,
    )
    return {
        "interests": interests,
        "trip_formats": trip_formats,
        "interest_weights": interest_weights,
        "budget": budget,
        "travel_mode": travel_mode,
        "pace": pace,
        "skipped": skipped,
        "has_completed": has_completed,
    }


def _profile_out_from_state(state: dict) -> SurveyProfileOut:
    normalized = _normalize_profile_state(state)
    return SurveyProfileOut(
        interests=normalized["interests"],
        trip_formats=normalized["trip_formats"],
        budget=normalized["budget"],
        travel_mode=normalized["travel_mode"],
        pace=normalized["pace"],
        interest_weights=normalized["interest_weights"],
        skipped=normalized["skipped"],
        has_completed=normalized["has_completed"],
    )


def _extract_scoped_profile(rows: list[UserPreference], trip_id: int | None) -> dict:
    state = _empty_profile_state()
    meta_key = SURVEY_PROFILE_META_KEY if trip_id is None else _trip_scoped_key(trip_id, SURVEY_PROFILE_META_KEY)
    interest_key = INTEREST_KEY if trip_id is None else _trip_scoped_key(trip_id, INTEREST_KEY)
    trip_format_key = TRIP_FORMAT_KEY if trip_id is None else _trip_scoped_key(trip_id, TRIP_FORMAT_KEY)
    weight_prefix = (
        INTEREST_WEIGHT_PREFIX
        if trip_id is None
        else _trip_scoped_key(trip_id, INTEREST_WEIGHT_PREFIX)
    )

    for row in rows:
        if row.key == interest_key:
            normalized = _normalize_value(row.value, INTEREST_ALIASES)
            if normalized is not None:
                state["interests"].append(normalized)
        elif row.key == trip_format_key:
            normalized = _normalize_value(row.value, TRIP_FORMAT_ALIASES)
            if normalized is not None:
                state["trip_formats"].append(normalized)
        elif row.key.startswith(weight_prefix):
            tag = _normalize_value(row.key[len(weight_prefix) :], INTEREST_ALIASES)
            if tag is None:
                continue
            try:
                weight = int(row.value)
            except ValueError:
                continue
            if 1 <= weight <= 5:
                state["interest_weights"][tag] = weight
        elif row.key == meta_key:
            try:
                meta = json.loads(row.value)
            except json.JSONDecodeError:
                continue
            state["budget"] = meta.get("budget") if isinstance(meta.get("budget"), str) else state["budget"]
            state["travel_mode"] = _normalize_value(
                meta.get("travel_mode") if isinstance(meta.get("travel_mode"), str) else state["travel_mode"],
                TRAVEL_MODE_ALIASES,
            )
            state["pace"] = meta.get("pace") if isinstance(meta.get("pace"), str) else state["pace"]
            state["skipped"] = bool(meta.get("skipped", state["skipped"]))

    return _normalize_profile_state(state)


def _aggregate_all_profile_states(rows: list[UserPreference]) -> dict:
    per_scope: dict[str, dict] = defaultdict(_empty_profile_state)

    for row in rows:
        scope = "global"
        raw_key = row.key
        if raw_key.startswith(TRIP_SURVEY_PREFIX):
            parts = raw_key.split(":", 2)
            if len(parts) != 3 or not parts[1].isdigit():
                continue
            scope = f"trip:{parts[1]}"
            raw_key = parts[2]

        state = per_scope[scope]
        if raw_key == INTEREST_KEY:
            normalized = _normalize_value(row.value, INTEREST_ALIASES)
            if normalized is not None:
                state["interests"].append(normalized)
        elif raw_key == TRIP_FORMAT_KEY:
            normalized = _normalize_value(row.value, TRIP_FORMAT_ALIASES)
            if normalized is not None:
                state["trip_formats"].append(normalized)
        elif raw_key.startswith(INTEREST_WEIGHT_PREFIX):
            tag = _normalize_value(raw_key[len(INTEREST_WEIGHT_PREFIX) :], INTEREST_ALIASES)
            if tag is None:
                continue
            try:
                weight = int(row.value)
            except ValueError:
                continue
            if 1 <= weight <= 5:
                state["interest_weights"][tag] = weight
        elif raw_key == SURVEY_PROFILE_META_KEY:
            try:
                meta = json.loads(row.value)
            except json.JSONDecodeError:
                continue
            state["budget"] = meta.get("budget") if isinstance(meta.get("budget"), str) else state["budget"]
            state["travel_mode"] = _normalize_value(
                meta.get("travel_mode") if isinstance(meta.get("travel_mode"), str) else state["travel_mode"],
                TRAVEL_MODE_ALIASES,
            )
            state["pace"] = meta.get("pace") if isinstance(meta.get("pace"), str) else state["pace"]
            state["skipped"] = bool(meta.get("skipped", state["skipped"]))

    normalized_states = [
        _normalize_profile_state(state)
        for state in per_scope.values()
        if state["interests"]
        or state["trip_formats"]
        or state["interest_weights"]
        or state["budget"] is not None
        or state["travel_mode"] is not None
        or state["pace"] is not None
        or state["skipped"]
    ]
    if not normalized_states:
        return _normalize_profile_state(_empty_profile_state())

    interests = sorted({tag for state in normalized_states for tag in state["interests"]})
    trip_formats = sorted({tag for state in normalized_states for tag in state["trip_formats"]})

    weights_bucket: dict[str, list[int]] = defaultdict(list)
    for state in normalized_states:
        for tag, weight in state["interest_weights"].items():
            weights_bucket[tag].append(weight)
    interest_weights = {
        tag: max(1, min(5, round(sum(values) / len(values))))
        for tag, values in weights_bucket.items()
        if values
    }

    budgets = [state["budget"] for state in normalized_states if state["budget"]]
    travel_modes = [state["travel_mode"] for state in normalized_states if state["travel_mode"]]
    paces = [state["pace"] for state in normalized_states if state["pace"]]
    skipped = all(state["skipped"] for state in normalized_states) and not (
        interests or trip_formats or interest_weights or budgets or travel_modes or paces
    )

    return _normalize_profile_state(
        {
            "interests": interests,
            "trip_formats": trip_formats,
            "interest_weights": interest_weights,
            "budget": Counter(budgets).most_common(1)[0][0] if budgets else None,
            "travel_mode": Counter(travel_modes).most_common(1)[0][0] if travel_modes else None,
            "pace": Counter(paces).most_common(1)[0][0] if paces else None,
            "skipped": skipped,
        }
    )


@router.get("/me/survey-profile", response_model=SurveyProfileOut)
def get_survey_profile(
    trip_id: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    rows = db.execute(
        select(UserPreference).where(UserPreference.user_id == me.id)
    ).scalars().all()
    state = (
        _extract_scoped_profile(rows, trip_id=trip_id)
        if trip_id is not None
        else _aggregate_all_profile_states(rows)
    )
    return _profile_out_from_state(state)


@router.post("/me/survey-profile", response_model=SurveyProfileOut)
def set_survey_profile(
    payload: SurveyProfileIn,
    trip_id: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    interest_key = INTEREST_KEY if trip_id is None else _trip_scoped_key(trip_id, INTEREST_KEY)
    trip_format_key = TRIP_FORMAT_KEY if trip_id is None else _trip_scoped_key(trip_id, TRIP_FORMAT_KEY)
    meta_key = SURVEY_PROFILE_META_KEY if trip_id is None else _trip_scoped_key(trip_id, SURVEY_PROFILE_META_KEY)
    interest_weight_prefix = (
        INTEREST_WEIGHT_PREFIX if trip_id is None else _trip_scoped_key(trip_id, INTEREST_WEIGHT_PREFIX)
    )

    db.execute(
        delete(UserPreference).where(
            UserPreference.user_id == me.id,
            (UserPreference.key == interest_key)
            | (UserPreference.key == trip_format_key)
            | (UserPreference.key == meta_key)
            | (UserPreference.key.like(f"{interest_weight_prefix}%")),
        )
    )

    for v in payload.interests:
        db.add(UserPreference(user_id=me.id, key=interest_key, value=v))

    for v in payload.trip_formats:
        db.add(UserPreference(user_id=me.id, key=trip_format_key, value=v))

    for tag, weight in payload.interest_weights.items():
        if not (1 <= weight <= 5):
            continue
        if not tag:
            continue
        db.add(
            UserPreference(
                user_id=me.id,
                key=f"{interest_weight_prefix}{tag}",
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
    db.add(UserPreference(user_id=me.id, key=meta_key, value=meta))
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
