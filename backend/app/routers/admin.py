import csv
import io
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select, delete, extract
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import require_role
from app.models.models import User, Milkman, Customer, AuditLog, MilkEntry, Feedback, RoleEnum

from app.services.audit import enrich_audit_logs

router = APIRouter(prefix="/admin", tags=["admin"])


class MilkmanCreate(BaseModel):
    name: str
    phone_number: str
    business_name: str | None = None
    address: str | None = None


class MilkmanOut(BaseModel):
    id: str
    name: str
    phone_number: str
    business_name: str | None
    is_active: bool

    class Config:
        from_attributes = True


@router.post("/milkmen", response_model=MilkmanOut, dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def create_milkman(body: MilkmanCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.phone_number == body.phone_number))
    if existing.scalar_one_or_none():
        raise HTTPException(409, "That phone number is already registered")

    user = User(
        phone_number=body.phone_number,
        role=RoleEnum.MILKMAN,
        is_active=True,
    )
    db.add(user)
    await db.flush()

    milkman = Milkman(
        user_id=user.id,
        name=body.name,
        phone_number=body.phone_number,
        business_name=body.business_name,
        address=body.address,
    )
    db.add(milkman)
    await db.commit()
    await db.refresh(milkman)

    return MilkmanOut(
        id=milkman.id,
        name=milkman.name,
        phone_number=milkman.phone_number,
        business_name=milkman.business_name,
        is_active=user.is_active,
    )


@router.get("/milkmen", response_model=list[MilkmanOut], dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def list_milkmen(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Milkman))
    milkmen = result.scalars().all()

    out = []
    for m in milkmen:
        user = await db.get(User, m.user_id)
        out.append(MilkmanOut(
            id=m.id, name=m.name, phone_number=m.phone_number,
            business_name=m.business_name, is_active=user.is_active,
        ))
    return out


@router.patch("/milkmen/{milkman_id}/suspend", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def suspend_milkman(milkman_id: str, db: AsyncSession = Depends(get_db)):
    milkman = await db.get(Milkman, milkman_id)
    if not milkman:
        raise HTTPException(404, "Milkman not found")
    user = await db.get(User, milkman.user_id)
    user.is_active = False
    await db.commit()
    return {"message": "Milkman suspended"}


class CustomerOut(BaseModel):
    id: str
    name: str
    phone_number: str
    milkman_id: str
    milkman_name: str
    device_locked: bool
    is_active: bool


@router.get("/customers", response_model=list[CustomerOut], dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def list_all_customers(db: AsyncSession = Depends(get_db)):
    """Every customer across every milkman - admin needs this to manage device locks."""
    result = await db.execute(select(Customer))
    customers = result.scalars().all()

    out = []
    for c in customers:
        user = await db.get(User, c.user_id)
        milkman = await db.get(Milkman, c.milkman_id)
        out.append(CustomerOut(
            id=c.id, name=c.name, phone_number=c.phone_number,
            milkman_id=c.milkman_id, milkman_name=milkman.name if milkman else "",
            device_locked=user.device_id is not None, is_active=c.is_active,
        ))
    return out


@router.post("/customers/{customer_id}/reset-device", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def admin_reset_customer_device(customer_id: str, db: AsyncSession = Depends(get_db)):
    """
    Only the admin can clear a customer's device lock - this was moved
    off the milkman on purpose so a milkman can't bump a customer off
    their own phone.
    """
    customer = await db.get(Customer, customer_id)
    if not customer:
        raise HTTPException(404, "Customer not found")

    user = await db.get(User, customer.user_id)
    user.device_id = None
    await db.commit()
    return {"message": "Device lock cleared. Customer can log in from a new device now."}


class AuditLogOut(BaseModel):
    id: str
    user_id: str
    action: str
    entity_type: str
    entity_id: str
    customer_id: str | None
    milkman_id: str | None
    metadata_json: dict | None
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("/audit-logs", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def admin_list_audit_logs(
    year: int | None = None,
    month: int | None = None,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc())
    if year is not None:
        stmt = stmt.where(extract("year", AuditLog.created_at) == year)
    if month is not None:
        stmt = stmt.where(extract("month", AuditLog.created_at) == month)
    result = await db.execute(stmt.limit(5000))
    logs = result.scalars().all()
    return await enrich_audit_logs(db, logs)


@router.get("/audit-logs/export", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def admin_export_audit_logs(year: int, month: int, db: AsyncSession = Depends(get_db)):
    """CSV export for one calendar month, for offline record-keeping."""
    stmt = (
        select(AuditLog)
        .where(extract("year", AuditLog.created_at) == year, extract("month", AuditLog.created_at) == month)
        .order_by(AuditLog.created_at)
    )
    result = await db.execute(stmt)
    logs = result.scalars().all()
    enriched = await enrich_audit_logs(db, logs)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow([
        "created_at", "action", "performed_by", "milkman_name", "customer_name",
        "entity_type", "entity_id", "details",
    ])
    for log in enriched:
        writer.writerow([
            log["created_at"], log["action"], log["performed_by"],
            log["milkman_name"] or "", log["customer_name"] or "",
            log["entity_type"], log["entity_id"], str(log["metadata_json"] or ""),
        ])
    buffer.seek(0)

    filename = f"audit_logs_{year}_{month:02d}.csv"
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.delete("/audit-logs/wipe", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def admin_wipe_audit_logs(
    year: int | None = None,
    month: int | None = None,
    confirm: bool = False,
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes audit log rows. Pass year+month to wipe just that month
    (recommended, after exporting it first). Omitting both wipes every
    log ever recorded - that requires confirm=true as a safety check.
    """
    if year is None and month is None and not confirm:
        raise HTTPException(400, "Wiping ALL logs requires confirm=true - this cannot be undone.")

    stmt = delete(AuditLog)
    if year is not None:
        stmt = stmt.where(extract("year", AuditLog.created_at) == year)
    if month is not None:
        stmt = stmt.where(extract("month", AuditLog.created_at) == month)

    result = await db.execute(stmt)
    await db.commit()
    return {"message": f"Deleted {result.rowcount} log entries."}


class MilkEntryOut(BaseModel):
    id: str
    delivery_date: date
    quantity_litres: float
    price_per_litre: float
    total_amount: float

    class Config:
        from_attributes = True


@router.get(
    "/customers/{customer_id}/milk-entries",
    response_model=list[MilkEntryOut],
    dependencies=[Depends(require_role(RoleEnum.ADMIN))],
)
async def admin_customer_milk_entries(customer_id: str, db: AsyncSession = Depends(get_db)):
    """
    Lets the admin see a customer's delivery history the same way a
    milkman can (used for the calendar popup on the admin's Customers page).
    """
    customer = await db.get(Customer, customer_id)
    if not customer:
        raise HTTPException(404, "Customer not found")

    result = await db.execute(
        select(MilkEntry)
        .where(MilkEntry.customer_id == customer_id, MilkEntry.is_deleted.is_(False))
        .order_by(MilkEntry.delivery_date.desc())
    )
    return result.scalars().all()


@router.get("/analysis", dependencies=[Depends(require_role(RoleEnum.ADMIN))])
async def admin_analysis(db: AsyncSession = Depends(get_db)):
    """System-wide usage stats, across every milkman - for the admin's Insights tab."""
    from sqlalchemy import func

    today = date.today()
    month_start = today.replace(day=1)

    milkman_count = (await db.execute(select(func.count(Milkman.id)))).scalar_one()
    customer_count = (await db.execute(select(func.count(Customer.id)))).scalar_one()

    result = await db.execute(
        select(
            func.count(MilkEntry.id),
            func.coalesce(func.sum(MilkEntry.quantity_litres), 0),
            func.coalesce(func.sum(MilkEntry.total_amount), 0),
        ).where(
            MilkEntry.is_deleted.is_(False),
            MilkEntry.delivery_date >= month_start,
            MilkEntry.delivery_date <= today,
        )
    )
    entries_this_month, litres_this_month, collection_this_month = result.one()

    avg_rating_result = await db.execute(select(func.avg(Feedback.rating)))
    avg_rating = avg_rating_result.scalar_one()
    feedback_count = (await db.execute(select(func.count(Feedback.id)))).scalar_one()

    return {
        "total_milkmen": milkman_count,
        "total_customers": customer_count,
        "entries_this_month": entries_this_month,
        "litres_this_month": float(litres_this_month),
        "collection_this_month": float(collection_this_month),
        "average_rating": round(float(avg_rating), 2) if avg_rating else None,
        "feedback_count": feedback_count,
    }
