from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class InteractionCreate(BaseModel):
    user_id: str = Field(min_length=1, max_length=64)
    place_id: str = Field(min_length=1, max_length=64)
    action: str = Field(pattern="^(shown|opened|liked|disliked|saved|added_to_trip|dismissed|shared)$")
    context: str = Field(default="recommendation", max_length=32)
    session_id: str | None = Field(default=None, max_length=64)
    recommendation_id: str | None = Field(default=None, max_length=64)
    weight: float = Field(default=1.0, ge=-10, le=10)
    metadata_json: dict[str, Any] | None = None


class InteractionOut(InteractionCreate):
    id: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ImpressionCreate(BaseModel):
    user_id: str = Field(min_length=1, max_length=64)
    place_id: str = Field(min_length=1, max_length=64)
    recommendation_id: str = Field(min_length=1, max_length=64)
    position: int = Field(ge=0, le=1000)
    context: str = Field(default="recommendation", max_length=32)


class UserInteractionSummary(BaseModel):
    user_id: str
    actions: dict[str, int]
    top_places: dict[str, float]


class PlaceInteractionSummary(BaseModel):
    place_id: str
    total_events: int
    actions: dict[str, int]
