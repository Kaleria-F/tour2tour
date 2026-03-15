from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class ExpenseCreate(BaseModel):
    description: str = Field(..., min_length=1, max_length=255)
    amount_rub: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)
    category: str = Field(..., min_length=1, max_length=32)


class ExpenseOut(BaseModel):
    id: int
    trip_id: int
    description: str
    amount_rub: Decimal
    category: str
    created_at: datetime

    class Config:
        from_attributes = True
