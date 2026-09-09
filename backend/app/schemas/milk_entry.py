from datetime import date, datetime
from pydantic import BaseModel


class MilkEntryCreate(BaseModel):
    customer_id: str
    delivery_date: date
    quantity_litres: float


class MilkEntryUpdate(BaseModel):
    quantity_litres: float | None = None
    delivery_date: date | None = None


class MilkEntryOut(BaseModel):
    id: str
    customer_id: str
    milkman_id: str
    delivery_date: date
    quantity_litres: float
    price_per_litre: float
    total_amount: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
