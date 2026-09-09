from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.models import User, Milkman, Customer, RoleEnum

bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = payload.get("sub")
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found or inactive")
    return user


def require_role(*allowed_roles: RoleEnum):
    async def checker(user: User = Depends(get_current_user)):
        if user.role not in allowed_roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not allowed for this role")
        return user
    return checker


async def get_current_milkman(
    user: User = Depends(require_role(RoleEnum.MILKMAN)),
    db: AsyncSession = Depends(get_db),
) -> Milkman:
    result = await db.execute(select(Milkman).where(Milkman.user_id == user.id))
    milkman = result.scalar_one_or_none()
    if not milkman:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Milkman profile not found")
    return milkman


async def get_current_customer(
    user: User = Depends(require_role(RoleEnum.CUSTOMER)),
    db: AsyncSession = Depends(get_db),
) -> Customer:
    result = await db.execute(select(Customer).where(Customer.user_id == user.id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Customer profile not found")
    return customer
