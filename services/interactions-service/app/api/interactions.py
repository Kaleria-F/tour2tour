from __future__ import annotations

import math
from collections import defaultdict
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.deps import get_db
from app.models.interaction import RecommendationImpression, UserPlaceInteraction
from app.schemas.interaction import (
    ImpressionCreate,
    InteractionCreate,
    InteractionOut,
    PlaceInteractionSummary,
    PlaceSignal,
    UserInteractionSummary,
)

router = APIRouter(prefix="/interactions", tags=["interactions"])


ACTION_WEIGHTS: dict[str, float] = {
    "shown": 0.2,
    "opened": 1.0,
    "liked": 4.0,
    "saved": 3.5,
    "added_to_trip": 5.0,
    "shared": 2.5,
    "dismissed": -2.0,
    "disliked": -5.0,
}


def _recency_multiplier(created_at: datetime | None) -> float:
    if created_at is None:
        return 0.4

    timestamp = created_at
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    age_days = max((datetime.now(timezone.utc) - timestamp).total_seconds() / 86400.0, 0.0)
    return max(0.25, math.exp(-age_days / 21.0))


@router.post("/events", response_model=InteractionOut, status_code=status.HTTP_201_CREATED)
def create_event(payload: InteractionCreate, db: Session = Depends(get_db)):
    event = UserPlaceInteraction(
        id=str(uuid4()),
        user_id=payload.user_id,
        place_id=payload.place_id,
        action=payload.action,
        context=payload.context,
        session_id=payload.session_id,
        recommendation_id=payload.recommendation_id,
        weight=payload.weight,
        metadata_json=payload.metadata_json,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return InteractionOut.model_validate(event)


@router.post("/impressions", status_code=status.HTTP_201_CREATED)
def create_impression(payload: ImpressionCreate, db: Session = Depends(get_db)):
    impression = RecommendationImpression(
        id=str(uuid4()),
        user_id=payload.user_id,
        place_id=payload.place_id,
        recommendation_id=payload.recommendation_id,
        position=payload.position,
        context=payload.context,
    )
    db.add(impression)
    db.commit()
    return {"ok": True, "id": impression.id}


@router.get("/users/{user_id}/summary", response_model=UserInteractionSummary)
def get_user_summary(
    user_id: str,
    limit: int = Query(default=200, ge=1, le=2000),
    db: Session = Depends(get_db),
):
    items = db.execute(
        select(UserPlaceInteraction)
        .where(UserPlaceInteraction.user_id == user_id)
        .order_by(UserPlaceInteraction.created_at.desc())
        .limit(limit)
    ).scalars().all()

    actions: dict[str, int] = defaultdict(int)
    place_scores: dict[str, float] = defaultdict(float)
    place_actions: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    last_actions: dict[str, str] = {}
    last_interacted_at: dict[str, datetime] = {}
    for item in items:
        actions[item.action] += 1
        place_actions[item.place_id][item.action] += 1
        if item.place_id not in last_actions:
            last_actions[item.place_id] = item.action
            last_interacted_at[item.place_id] = item.created_at

        action_weight = ACTION_WEIGHTS.get(item.action, item.weight)
        place_scores[item.place_id] += action_weight * _recency_multiplier(item.created_at)

    top_places = dict(sorted(place_scores.items(), key=lambda x: x[1], reverse=True)[:50])
    place_signals = {
        place_id: PlaceSignal(
            score=round(place_scores.get(place_id, 0.0), 3),
            actions=dict(action_counts),
            last_action=last_actions.get(place_id),
            last_interacted_at=last_interacted_at.get(place_id),
        )
        for place_id, action_counts in place_actions.items()
    }
    return UserInteractionSummary(
        user_id=user_id,
        actions=dict(actions),
        top_places=top_places,
        place_signals=place_signals,
    )


@router.get("/places/{place_id}/summary", response_model=PlaceInteractionSummary)
def get_place_summary(place_id: str, db: Session = Depends(get_db)):
    rows = db.execute(
        select(UserPlaceInteraction.action, func.count())
        .where(UserPlaceInteraction.place_id == place_id)
        .group_by(UserPlaceInteraction.action)
    ).all()
    actions = {action: count for action, count in rows}
    total = sum(actions.values())
    return PlaceInteractionSummary(place_id=place_id, total_events=total, actions=actions)
