"""
Central place for two things:
1. record_audit()  -> called anywhere an entry is created/edited/deleted/price changed
2. get_audit_logs() -> the ONLY way audit logs are ever read, with role-based
                        filtering baked in so a customer can never see anyone
                        else's logs, and a milkman can never see another
                        milkman's logs. Admin sees everything.

Never bypass this module by writing a raw query against AuditLog elsewhere.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import AuditLog, User, Customer, Milkman, RoleEnum


async def record_audit(
    db: AsyncSession,
    *,
    user_id: str,
    action: str,
    entity_type: str,
    entity_id: str,
    customer_id: str | None = None,
    milkman_id: str | None = None,
    old_value: dict | None = None,
    new_value: dict | None = None,
) -> AuditLog:
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        customer_id=customer_id,
        milkman_id=milkman_id,
        metadata_json={"old": old_value, "new": new_value} if (old_value or new_value) else None,
    )
    db.add(log)
    await db.flush()  # caller commits as part of its own transaction
    return log


async def get_audit_logs(
    db: AsyncSession,
    *,
    requester_role: RoleEnum,
    requester_user_id: str,
    requester_milkman_id: str | None = None,
    requester_customer_id: str | None = None,
    limit: int = 100,
):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)

    if requester_role == RoleEnum.ADMIN:
        pass  # no filter - sees everything

    elif requester_role == RoleEnum.MILKMAN:
        stmt = stmt.where(AuditLog.milkman_id == requester_milkman_id)

    elif requester_role == RoleEnum.CUSTOMER:
        # A customer only ever sees rows tied to their own customer_id
        stmt = stmt.where(AuditLog.customer_id == requester_customer_id)

    else:
        return []

    result = await db.execute(stmt)
    return result.scalars().all()


async def enrich_audit_logs(db: AsyncSession, logs: list[AuditLog]) -> list[dict]:
    """
    Adds human-readable names to raw audit rows: which customer, which
    milkman, and who actually performed the action. Batches the lookups
    so this stays cheap even for a long log list.
    """
    customer_ids = {log.customer_id for log in logs if log.customer_id}
    milkman_ids = {log.milkman_id for log in logs if log.milkman_id}
    user_ids = {log.user_id for log in logs if log.user_id}

    customers = {}
    if customer_ids:
        result = await db.execute(select(Customer).where(Customer.id.in_(customer_ids)))
        customers = {c.id: c.name for c in result.scalars().all()}

    milkmen = {}
    if milkman_ids:
        result = await db.execute(select(Milkman).where(Milkman.id.in_(milkman_ids)))
        milkmen = {m.id: m.name for m in result.scalars().all()}

    users = {}
    if user_ids:
        result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users = {u.id: u for u in result.scalars().all()}

    out = []
    for log in logs:
        actor = users.get(log.user_id)
        if actor and actor.role == RoleEnum.ADMIN:
            performed_by = actor.username or "Admin"
        elif actor and log.milkman_id and log.milkman_id in milkmen:
            performed_by = milkmen[log.milkman_id]
        else:
            performed_by = "Unknown"

        out.append({
            "id": log.id,
            "action": log.action,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "customer_id": log.customer_id,
            "customer_name": customers.get(log.customer_id),
            "milkman_id": log.milkman_id,
            "milkman_name": milkmen.get(log.milkman_id),
            "performed_by": performed_by,
            "metadata_json": log.metadata_json,
            "created_at": log.created_at.isoformat(),
        })
    return out
