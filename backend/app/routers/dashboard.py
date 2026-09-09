from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_milkman
from app.models.models import MilkEntry, Customer, MilkPrice, Milkman

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/profile")
async def milkman_profile(milkman: Milkman = Depends(get_current_milkman)):
    return {
        "id": milkman.id,
        "name": milkman.name,
        "business_name": milkman.business_name,
        "phone_number": milkman.phone_number,
    }


@router.get("/summary")
async def milkman_summary(    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    today = date.today()
    month_start = today.replace(day=1)

    # Deliveries + total litres + collection, this month
    result = await db.execute(
        select(
            func.count(MilkEntry.id),
            func.coalesce(func.sum(MilkEntry.quantity_litres), 0),
            func.coalesce(func.sum(MilkEntry.total_amount), 0),
        ).where(
            MilkEntry.milkman_id == milkman.id,
            MilkEntry.is_deleted.is_(False),
            MilkEntry.delivery_date >= month_start,
            MilkEntry.delivery_date <= today,
        )
    )
    deliveries_count, total_litres, total_collection = result.one()

    # Current price
    price_result = await db.execute(
        select(MilkPrice).where(
            MilkPrice.milkman_id == milkman.id,
            MilkPrice.effective_from <= today,
            (MilkPrice.effective_until.is_(None)) | (MilkPrice.effective_until >= today),
        )
    )
    current_price = price_result.scalar_one_or_none()

    # Pending = active customers with no entry logged today
    total_customers_result = await db.execute(
        select(func.count(Customer.id)).where(Customer.milkman_id == milkman.id, Customer.is_active.is_(True))
    )
    total_customers = total_customers_result.scalar_one()

    todays_customers_result = await db.execute(
        select(func.count(func.distinct(MilkEntry.customer_id))).where(
            MilkEntry.milkman_id == milkman.id,
            MilkEntry.is_deleted.is_(False),
            MilkEntry.delivery_date == today,
        )
    )
    todays_customers_count = todays_customers_result.scalar_one()
    pending_count = max(total_customers - todays_customers_count, 0)

    return {
        "deliveries_this_month": deliveries_count,
        "total_litres_this_month": float(total_litres),
        "total_collection_this_month": float(total_collection),
        "current_price_per_litre": float(current_price.price_per_litre) if current_price else None,
        "pending_today": pending_count,
        "total_customers": total_customers,
    }


@router.get("/analysis")
async def milkman_analysis(
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    """Last 6 months of totals, plus top customers by volume this month."""
    today = date.today()

    months = []
    for i in range(5, -1, -1):
        month = today.month - i
        year = today.year
        while month <= 0:
            month += 12
            year -= 1
        months.append((year, month))

    monthly_totals = []
    for year, month in months:
        start = date(year, month, 1)
        end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
        result = await db.execute(
            select(
                func.coalesce(func.sum(MilkEntry.quantity_litres), 0),
                func.coalesce(func.sum(MilkEntry.total_amount), 0),
            ).where(
                MilkEntry.milkman_id == milkman.id,
                MilkEntry.is_deleted.is_(False),
                MilkEntry.delivery_date >= start,
                MilkEntry.delivery_date < end,
            )
        )
        litres, collection = result.one()
        monthly_totals.append({
            "year": year, "month": month,
            "total_litres": float(litres), "total_collection": float(collection),
        })

    month_start = today.replace(day=1)
    top_result = await db.execute(
        select(
            Customer.id, Customer.name,
            func.sum(MilkEntry.quantity_litres).label("total_litres"),
        )
        .join(MilkEntry, MilkEntry.customer_id == Customer.id)
        .where(
            MilkEntry.milkman_id == milkman.id,
            MilkEntry.is_deleted.is_(False),
            MilkEntry.delivery_date >= month_start,
            MilkEntry.delivery_date <= today,
        )
        .group_by(Customer.id, Customer.name)
        .order_by(func.sum(MilkEntry.quantity_litres).desc())
        .limit(5)
    )
    top_customers = [
        {"id": row.id, "name": row.name, "total_litres": float(row.total_litres)}
        for row in top_result.all()
    ]

    return {"monthly_totals": monthly_totals, "top_customers_this_month": top_customers}
