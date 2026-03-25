from __future__ import annotations

from collections import defaultdict
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
    UserInteractionSummary,
)

router = APIRouter(prefix="/interactions", tags=["interactions"])


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
    for item in items:
        actions[item.action] += 1
        place_scores[item.place_id] += item.weight

    top_places = dict(sorted(place_scores.items(), key=lambda x: x[1], reverse=True)[:50])
    return UserInteractionSummary(user_id=user_id, actions=dict(actions), top_places=top_places)


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
