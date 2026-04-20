from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class PlaceBase(BaseModel):
    external_id: str | None = None
    source: str = Field(min_length=1, max_length=64)
    status: str = "approved"
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    image_url: str | None = None
    country: str | None = None
    city: str = Field(min_length=1, max_length=128)
    address: str | None = None
    lat: float | None = None
    lon: float | None = None
    category: str = Field(min_length=1, max_length=64)
    subcategory: str | None = None
    price_level: str | None = None
    avg_visit_duration_min: int | None = Field(default=None, ge=0, le=1440)
    rating: float | None = Field(default=None, ge=0, le=5)
    reviews_count: int | None = Field(default=0, ge=0)
    working_hours_json: dict[str, Any] | None = None
    metadata_json: dict[str, Any] | None = None
    tags: dict[str, int] = Field(default_factory=dict)


class PlaceCreate(PlaceBase):
    pass


class PlaceUpdate(BaseModel):
    external_id: str | None = None
    source: str | None = None
    status: str | None = None
    name: str | None = None
    description: str | None = None
    image_url: str | None = None
    country: str | None = None
    city: str | None = None
    address: str | None = None
    lat: float | None = None
    lon: float | None = None
    category: str | None = None
    subcategory: str | None = None
    price_level: str | None = None
    avg_visit_duration_min: int | None = Field(default=None, ge=0, le=1440)
    rating: float | None = Field(default=None, ge=0, le=5)
    reviews_count: int | None = Field(default=None, ge=0)
    working_hours_json: dict[str, Any] | None = None
    metadata_json: dict[str, Any] | None = None
    tags: dict[str, int] | None = None


class PlaceOut(PlaceBase):
    id: str
    created_at: datetime
    updated_at: datetime


class PlaceListResponse(BaseModel):
    items: list[PlaceOut]
    total: int


class CitySuggestionOut(BaseModel):
    city: str
    region: str | None = None
    district: str | None = None
    country: str = "Россия"
    display_name: str
    lat: float | None = None
    lon: float | None = None
    population: int | None = None
    type: str | None = None
    source: str


class PlaceCandidateOut(BaseModel):
    id: str
    source: str
    source_record_id: str | None
    status: str
    payload_json: dict[str, Any]
    normalized_json: dict[str, Any] | None
    validation_score: float | None
    notes: str | None
    created_at: datetime
    updated_at: datetime


class PlaceCandidateDecision(BaseModel):
    status: str = Field(pattern="^(approved|rejected|pending_review)$")
    notes: str | None = None


class ImportJobCreate(BaseModel):
    source: str = Field(min_length=1, max_length=64)
    kind: str = Field(min_length=1, max_length=32)
    file_name: str | None = None
    created_by: str | None = None


class ImportJobOut(ImportJobCreate):
    id: str
    status: str
    stats_json: dict[str, Any]
    created_at: datetime | None = None
    updated_at: datetime | None = None
