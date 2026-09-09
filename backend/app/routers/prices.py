from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_milkman
from app.models.models import MilkPrice, Milkman
from app.services.audit import record_audit

router = APIRouter(prefix="/prices", tags=["prices"])


class PriceCreate(BaseModel):
    price_per_litre: float
    effective_from: date | None = None  # defaults to today if omitted


class PriceOut(BaseModel):
    id: str
    price_per_litre: float
    effective_from: date
    effective_until: date | None

    class Config:
        from_attributes = True


@router.post("", response_model=PriceOut)
async def set_new_price(
    body: PriceCreate,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    effective_from = body.effective_from or date.today()

    # Close out any currently-open price window (Rule 3/4: never rewrite history)
    result = await db.execute(
        select(MilkPrice).where(
            MilkPrice.milkman_id == milkman.id, MilkPrice.effective_until.is_(None)
        )
    )
    open_price = result.scalar_one_or_none()

    # Rate can be set for the first time any time, but after that it's
    # locked to once per calendar month.
    if open_price and (
        open_price.effective_from.year == effective_from.year
        and open_price.effective_from.month == effective_from.month
    ):
        raise HTTPException(
            400,
            f"Milk rate was already set this month (on {open_price.effective_from}). "
            "It can only be changed once per month.",
        )

    if open_price:
        open_price.effective_until = effective_from

    new_price = MilkPrice(
        milkman_id=milkman.id,
        price_per_litre=body.price_per_litre,
        effective_from=effective_from,
    )
    db.add(new_price)
    await db.flush()

    await record_audit(
        db,
        user_id=milkman.user_id,
        action="PRICE_CHANGED",
        entity_type="milk_price",
        entity_id=new_price.id,
        milkman_id=milkman.id,
        old_value={"price": float(open_price.price_per_litre)} if open_price else None,
        new_value={"price": body.price_per_litre, "effective_from": str(effective_from)},
    )

    await db.commit()
    await db.refresh(new_price)
    return new_price


@router.get("", response_model=list[PriceOut])
async def price_history(
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    result = await db.execute(
        select(MilkPrice).where(MilkPrice.milkman_id == milkman.id).order_by(MilkPrice.effective_from.desc())
    )
    return result.scalars().all()
