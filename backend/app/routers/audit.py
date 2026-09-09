from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, get_current_milkman, get_current_customer
from app.models.models import User, Milkman, Customer, RoleEnum
from app.services.audit import get_audit_logs

router = APIRouter(prefix="/audit-logs", tags=["audit"])


@router.get("/admin")
async def admin_view_all_logs(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # get_current_user + role check happens inside get_audit_logs via role param;
    # but we still gate the route itself:
    if user.role != RoleEnum.ADMIN:
        from fastapi import HTTPException
        raise HTTPException(403, "Admin only")
    return await get_audit_logs(db, requester_role=RoleEnum.ADMIN, requester_user_id=user.id)


@router.get("/milkman")
async def milkman_view_own_logs(
    db: AsyncSession = Depends(get_db),
    milkman: Milkman = Depends(get_current_milkman),
):
    return await get_audit_logs(
        db,
        requester_role=RoleEnum.MILKMAN,
        requester_user_id=milkman.user_id,
        requester_milkman_id=milkman.id,
    )


@router.get("/me")
async def customer_view_own_logs(
    db: AsyncSession = Depends(get_db),
    customer: Customer = Depends(get_current_customer),
):
    """A customer only ever sees changes to their own entries."""
    return await get_audit_logs(
        db,
        requester_role=RoleEnum.CUSTOMER,
        requester_user_id=customer.user_id,
        requester_customer_id=customer.id,
    )
