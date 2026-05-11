from pydantic import BaseModel, Field


class ProCheckoutCreateIn(BaseModel):
    return_url: str | None = None
    source: str | None = Field(default=None, max_length=64)


class ProCheckoutCreateOut(BaseModel):
    payment_id: str
    status: str
    confirmation_url: str
    amount_value: str
    currency: str
    is_test: bool | None = None


class PaymentStatusOut(BaseModel):
    payment_id: str
    status: str
    paid: bool
    is_premium_activated: bool
    amount_value: str | None = None
    currency: str | None = None
    confirmation_url: str | None = None
    is_test: bool | None = None
