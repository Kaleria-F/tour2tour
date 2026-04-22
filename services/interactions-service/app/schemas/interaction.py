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


class PlaceSignal(BaseModel):
    score: float = 0.0
    actions: dict[str, int] = Field(default_factory=dict)
    last_action: str | None = None
    last_interacted_at: datetime | None = None


class UserInteractionSummary(BaseModel):
    user_id: str
    actions: dict[str, int]
    top_places: dict[str, float]
    place_signals: dict[str, PlaceSignal] = Field(default_factory=dict)


class PlaceInteractionSummary(BaseModel):
    place_id: str
    total_events: int
    actions: dict[str, int]


class FavoritePlace(BaseModel):
    place_id: str
    title: str
    city: str
    address: str | None = None
    image_url: str | None = None
    category: str | None = None
    subcategory: str | None = None
    rating: float | None = None
    description: str | None = None
    trip_id: int | None = None
    trip_title: str | None = None
    saved_at: datetime | None = None
    last_action: str | None = None


class FavoriteCityGroup(BaseModel):
    city: str
    items: list[FavoritePlace]
