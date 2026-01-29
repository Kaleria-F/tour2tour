from datetime import date
from pydantic import BaseModel, Field


class TripCreate(BaseModel):
    title: str = Field(..., max_length=255)
    description: str | None = Field(None, max_length=500)
    start_date: date = Field(..., example="2026-05-10")
    end_date: date = Field(..., example="2026-05-15")


class TripOut(BaseModel):
    id: int
    title: str
    description: str | None
    start_date: date
    end_date: date

    class Config:
        from_attributes = True
