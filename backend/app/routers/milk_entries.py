from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_milkman, get_current_customer
from app.models.models import MilkEntry, MilkPrice, Customer, Notification, Milkman
from app.schemas.milk_entry import MilkEntryCreate, MilkEntryUpdate, MilkEntryOut
from app.services.audit import record_audit

router = APIRouter(prefix="/milk-entries", tags=["milk-entries"])


async def _current_price(db: AsyncSession, milkman_id: str, on_date: date) -> float:
    result = await db.execute(
        select(MilkPrice).where(
            MilkPrice.milkman_id == milkman_id,
            MilkPrice.effective_from <= on_date,
            (MilkPrice.effective_until.is_(None)) | (MilkPrice.effective_until >= on_date),
        )
    )
    price_row = result.scalar_one_or_none()
    if not price_row:
        raise HTTPException(400, "No price set for this date. Set a milk price first.")
    return float(price_row.price_per_litre)


def _notification_message(delivery_date: date, quantity_litres: float) -> str:
    """
    Hindi message for today's milk, since that's what the customer actually
    cares about seeing right away. Back-dated entries get a neutral message
    instead, since 'aaj ka dudh' (today's milk) wouldn't make sense for them.
    """
    if delivery_date == date.today():
        return f"आज का दूध: {quantity_litres} L"
    return f"{quantity_litres} L milk recorded for {delivery_date}."


@router.post("", response_model=MilkEntryOut)
async def create_milk_entry(
    body: MilkEntryCreate,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    # Duplicate entry protection: one entry per customer per date (Section 14 of roadmap)
    existing = await db.execute(
        select(MilkEntry).where(
            MilkEntry.customer_id == body.customer_id,
            MilkEntry.delivery_date == body.delivery_date,
            MilkEntry.is_deleted.is_(False),
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(409, "An entry already exists for this customer on this date")

    customer = await db.get(Customer, body.customer_id)
    if not customer or customer.milkman_id != milkman.id:
        raise HTTPException(404, "Customer not found under this milkman")

    price = await _current_price(db, milkman.id, body.delivery_date)
    total = round(price * body.quantity_litres, 2)

    entry = MilkEntry(
        customer_id=customer.id,
        milkman_id=milkman.id,
        delivery_date=body.delivery_date,
        quantity_litres=body.quantity_litres,
        price_per_litre=price,
        total_amount=total,
        created_by=milkman.user_id,
    )
    db.add(entry)
    await db.flush()

    await record_audit(
        db,
        user_id=milkman.user_id,
        action="MILK_ENTRY_CREATED",
        entity_type="milk_entry",
        entity_id=entry.id,
        customer_id=customer.id,
        milkman_id=milkman.id,
        new_value={"quantity": body.quantity_litres, "price": price, "total": total},
    )

    db.add(Notification(
        user_id=customer.user_id,
        title="Milk Entry Added",
        message=_notification_message(body.delivery_date, body.quantity_litres),
        type="MILK_ENTRY_CREATED",
        reference_id=entry.id,
    ))

    await db.commit()
    await db.refresh(entry)
    return entry


@router.patch("/{entry_id}", response_model=MilkEntryOut)
async def update_milk_entry(
    entry_id: str,
    body: MilkEntryUpdate,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    entry = await db.get(MilkEntry, entry_id)
    if not entry or entry.milkman_id != milkman.id or entry.is_deleted:
        raise HTTPException(404, "Entry not found")

    if entry.delivery_date != date.today():
        raise HTTPException(403, "Only today's entries can be edited. Past entries are locked.")

    old_value = {"quantity": float(entry.quantity_litres), "total": float(entry.total_amount)}

    if body.quantity_litres is not None:
        entry.quantity_litres = body.quantity_litres
        entry.total_amount = round(float(entry.price_per_litre) * body.quantity_litres, 2)
    if body.delivery_date is not None:
        entry.delivery_date = body.delivery_date

    await record_audit(
        db,
        user_id=milkman.user_id,
        action="MILK_ENTRY_UPDATED",
        entity_type="milk_entry",
        entity_id=entry.id,
        customer_id=entry.customer_id,
        milkman_id=milkman.id,
        old_value=old_value,
        new_value={"quantity": float(entry.quantity_litres), "total": float(entry.total_amount)},
    )

    customer = await db.get(Customer, entry.customer_id)
    db.add(Notification(
        user_id=customer.user_id,
        title="Milk Entry Updated",
        message=_notification_message(entry.delivery_date, float(entry.quantity_litres)),
        type="MILK_ENTRY_UPDATED",
        reference_id=entry.id,
    ))

    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/{entry_id}")
async def delete_milk_entry(
    entry_id: str,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    entry = await db.get(MilkEntry, entry_id)
    if not entry or entry.milkman_id != milkman.id or entry.is_deleted:
        raise HTTPException(404, "Entry not found")

    entry.is_deleted = True  # soft delete (Rule 8)

    await record_audit(
        db,
        user_id=milkman.user_id,
        action="MILK_ENTRY_DELETED",
        entity_type="milk_entry",
        entity_id=entry.id,
        customer_id=entry.customer_id,
        milkman_id=milkman.id,
        old_value={"quantity": float(entry.quantity_litres), "total": float(entry.total_amount)},
    )

    customer = await db.get(Customer, entry.customer_id)
    db.add(Notification(
        user_id=customer.user_id,
        title="Milk Entry Removed",
        message=f"Your entry for {entry.delivery_date} was removed by your milkman.",
        type="MILK_ENTRY_DELETED",
        reference_id=entry.id,
    ))

    await db.commit()
    return {"message": "Entry soft-deleted"}


@router.get("/customer/{customer_id}", response_model=list[MilkEntryOut])
async def list_customer_entries(
    customer_id: str,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    customer = await db.get(Customer, customer_id)
    if not customer or customer.milkman_id != milkman.id:
        raise HTTPException(404, "Customer not found")

    result = await db.execute(
        select(MilkEntry)
        .where(MilkEntry.customer_id == customer_id, MilkEntry.is_deleted.is_(False))
        .order_by(MilkEntry.delivery_date.desc())
    )
    return result.scalars().all()


@router.get("/me", response_model=list[MilkEntryOut])
async def my_entries(
    db: AsyncSession = Depends(get_db),
    customer: Customer = Depends(get_current_customer),
):
    """Customer-facing: only ever their own entries."""
    result = await db.execute(
        select(MilkEntry)
        .where(MilkEntry.customer_id == customer.id, MilkEntry.is_deleted.is_(False))
        .order_by(MilkEntry.delivery_date.desc())
    )
    return result.scalars().all()
