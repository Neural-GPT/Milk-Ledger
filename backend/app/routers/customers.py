from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_milkman, get_current_customer
from app.models.models import Customer, User, Milkman, MilkEntry, RoleEnum
from app.services.audit import record_audit

router = APIRouter(prefix="/customers", tags=["customers"])


class CustomerCreate(BaseModel):
    name: str
    phone_number: str
    address: str | None = None


class CustomerOut(BaseModel):
    id: str
    name: str
    phone_number: str
    address: str | None
    is_active: bool

    class Config:
        from_attributes = True


@router.post("", response_model=CustomerOut)
async def add_customer(
    body: CustomerCreate,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    existing = await db.execute(select(User).where(User.phone_number == body.phone_number))
    if existing.scalar_one_or_none():
        raise HTTPException(409, "A user with this phone number already exists")

    user = User(phone_number=body.phone_number, role=RoleEnum.CUSTOMER)
    db.add(user)
    await db.flush()

    customer = Customer(
        user_id=user.id,
        milkman_id=milkman.id,
        name=body.name,
        phone_number=body.phone_number,
        address=body.address,
    )
    db.add(customer)
    await db.flush()

    await record_audit(
        db,
        user_id=milkman.user_id,
        action="CUSTOMER_CREATED",
        entity_type="customer",
        entity_id=customer.id,
        customer_id=customer.id,
        milkman_id=milkman.id,
        new_value={"name": body.name, "phone_number": body.phone_number},
    )

    await db.commit()
    await db.refresh(customer)
    return customer


@router.get("/search", response_model=list[CustomerOut])
async def search_customers(
    q: str,
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    result = await db.execute(
        select(Customer).where(
            Customer.milkman_id == milkman.id,
            or_(Customer.name.ilike(f"%{q}%"), Customer.phone_number.ilike(f"%{q}%")),
        )
    )
    return result.scalars().all()


@router.get("", response_model=list[CustomerOut])
async def list_my_customers(
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    result = await db.execute(select(Customer).where(Customer.milkman_id == milkman.id))
    return result.scalars().all()


@router.get("/recent")
async def recent_customers(
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    """
    Customers with their most recent milk entry, most recently delivered
    first - powers the 'Recent Customers' row on the milkman dashboard.
    """
    result = await db.execute(
        select(Customer, MilkEntry)
        .outerjoin(
            MilkEntry,
            (MilkEntry.customer_id == Customer.id) & (MilkEntry.is_deleted.is_(False)),
        )
        .where(Customer.milkman_id == milkman.id, Customer.is_active.is_(True))
        .order_by(desc(MilkEntry.delivery_date))
    )
    rows = result.all()

    today_str = str(date.today())
    seen = set()
    out = []
    for customer, entry in rows:
        if customer.id in seen:
            continue
        seen.add(customer.id)
        out.append({
            "id": customer.id,
            "name": customer.name,
            "phone_number": customer.phone_number,
            "last_quantity_litres": float(entry.quantity_litres) if entry else None,
            "last_delivery_date": str(entry.delivery_date) if entry else None,
            "has_entry_today": entry is not None and str(entry.delivery_date) == today_str,
        })
    return out[:10]


@router.get("/me", response_model=CustomerOut)
async def my_profile(customer: Customer = Depends(get_current_customer)):
    return customer
