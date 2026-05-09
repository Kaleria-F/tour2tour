from datetime import date
from pydantic import BaseModel, Field


class TripCreate(BaseModel):
    title: str = Field(..., max_length=255)
    description: str | None = Field(None, max_length=500)
    destination_city: str | None = Field(None, max_length=128)
    start_date: date = Field(..., example="2026-05-10")
    end_date: date = Field(..., example="2026-05-15")
    planned_days: int | None = Field(None, ge=1, le=365)
    card_color: str | None = Field(None, max_length=16)
    card_background: str | None = Field(None, max_length=32)
    card_icon: str | None = Field(None, max_length=32)
    is_archived: bool | None = Field(False)


class TripOut(BaseModel):
    id: int
    title: str
    description: str | None
    destination_city: str | None
    start_date: date
    end_date: date
    planned_days: int | None
    card_color: str | None
    card_background: str | None
    card_icon: str | None
    is_archived: bool

    class Config:
        from_attributes = True


class TripUpdate(BaseModel):
    title: str | None = Field(None, max_length=255)
    start_date: date | None = Field(None, example="2026-05-10")
    end_date: date | None = Field(None, example="2026-05-15")
    planned_days: int | None = Field(None, ge=1, le=365)
    card_color: str | None = Field(None, max_length=16)
    card_background: str | None = Field(None, max_length=32)
    card_icon: str | None = Field(None, max_length=32)
    is_archived: bool | None = None
    confirm_trim: bool = Field(False)
