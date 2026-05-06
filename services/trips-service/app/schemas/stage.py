from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class StageBase(BaseModel):
    stage_type: str = Field(..., min_length=1, max_length=32)
    subtype: str = Field(..., min_length=1, max_length=64)
    title: str = Field(..., min_length=1, max_length=255)

    start_location: str | None = Field(None, max_length=255)
    end_location: str | None = Field(None, max_length=255)
    address: str | None = Field(None, max_length=255)
    latitude: float | None = None
    longitude: float | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    duration_minutes: int | None = Field(None, ge=0)
    cost_rub: Decimal | None = Field(None, ge=0, max_digits=12, decimal_places=2)
    reference_number: str | None = Field(None, max_length=128)
    website_url: str | None = Field(None, max_length=512)
    rating: float | None = Field(None, ge=0, le=5)
    notes: str | None = None
    document_key: str | None = Field(None, max_length=512)


class StageCreate(StageBase):
    pass


class StageUpdate(BaseModel):
    stage_type: str | None = Field(None, min_length=1, max_length=32)
    subtype: str | None = Field(None, min_length=1, max_length=64)
    title: str | None = Field(None, min_length=1, max_length=255)

    start_location: str | None = Field(None, max_length=255)
    end_location: str | None = Field(None, max_length=255)
    address: str | None = Field(None, max_length=255)
    latitude: float | None = None
    longitude: float | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    duration_minutes: int | None = Field(None, ge=0)
    cost_rub: Decimal | None = Field(None, ge=0, max_digits=12, decimal_places=2)
    reference_number: str | None = Field(None, max_length=128)
    website_url: str | None = Field(None, max_length=512)
    rating: float | None = Field(None, ge=0, le=5)
    notes: str | None = None
    document_key: str | None = Field(None, max_length=512)


class StageOut(StageBase):
    id: int
    trip_id: int
    position: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class StageReorderRequest(BaseModel):
    stage_ids: list[int] = Field(default_factory=list)


class StageSuggestionOut(BaseModel):
    title: str
    stage_type: str
    subtype: str
    reason: str
    start_location: str | None = None
    end_location: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    estimated_cost_rub: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=12,
        decimal_places=2,
    )


class StageAssistantDraftRequest(BaseModel):
    stage_type: str = Field(..., min_length=1, max_length=32)
    text: str = Field(..., min_length=1, max_length=4000)
    route_day: date | None = None


class StageAssistantDraftOut(BaseModel):
    stage_type: str
    subtype: str
    title: str
    start_location: str | None = Field(None, max_length=255)
    end_location: str | None = Field(None, max_length=255)
    address: str | None = Field(None, max_length=255)
    start_time_text: str | None = Field(None, max_length=5)
    end_time_text: str | None = Field(None, max_length=5)
    duration_minutes: int | None = Field(None, ge=0)
    cost_rub: Decimal | None = Field(None, ge=0, max_digits=12, decimal_places=2)
    notes: str | None = None
    time_mode: str = Field(default="duration", max_length=16)
    source_text: str = Field(..., min_length=1)


class StageAssistantTranscriptionOut(BaseModel):
    text: str = Field(..., min_length=1)
