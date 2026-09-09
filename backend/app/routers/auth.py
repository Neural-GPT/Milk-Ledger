from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import verify_value, create_access_token
from app.models.models import User, Milkman, RoleEnum

router = APIRouter(prefix="/auth", tags=["auth"])


class PasswordLoginBody(BaseModel):
    username: str
    password: str


class MilkmanLoginBody(BaseModel):
    phone_number: str
    name: str


class CustomerLoginBody(BaseModel):
    phone_number: str
    device_id: str  # generated once on-device and stored locally


def _issue_token(user: User) -> dict:
    token = create_access_token(subject=user.id, role=user.role.value)
    return {"access_token": token, "token_type": "bearer", "role": user.role.value}


@router.post("/admin-login")
async def admin_login(body: PasswordLoginBody, db: AsyncSession = Depends(get_db)):
    """Admin account is pre-created via scripts/create_admin.py - no self-registration."""
    result = await db.execute(
        select(User).where(User.username == body.username, User.role == RoleEnum.ADMIN)
    )
    user = result.scalar_one_or_none()

    if not user or not user.password_hash or not verify_value(body.password, user.password_hash):
        raise HTTPException(401, "Invalid username or password")
    if not user.is_active:
        raise HTTPException(403, "Account suspended")

    return _issue_token(user)


@router.post("/milkman-login")
async def milkman_login(body: MilkmanLoginBody, db: AsyncSession = Depends(get_db)):
    """
    Milkman logs in with the name + phone number the admin registered them
    with (see /admin/milkmen) - no separate password to remember.
    """
    result = await db.execute(
        select(User).where(User.phone_number == body.phone_number, User.role == RoleEnum.MILKMAN)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(404, "No milkman account found for this number. Ask the admin to register you.")
    if not user.is_active:
        raise HTTPException(403, "Account suspended")

    milkman_result = await db.execute(select(Milkman).where(Milkman.user_id == user.id))
    milkman = milkman_result.scalar_one_or_none()

    if not milkman or milkman.name.strip().lower() != body.name.strip().lower():
        raise HTTPException(401, "Name doesn't match our records for this number")

    return _issue_token(user)


@router.post("/customer-login")
async def customer_login(body: CustomerLoginBody, db: AsyncSession = Depends(get_db)):
    """
    Phone number only, no password/OTP. A customer's phone number gets
    locked to whichever device first logs in with it - after that, the
    same phone number can't be used to log in from a different device
    unless the milkman resets it (see /customers/{id}/reset-device).
    """
    result = await db.execute(
        select(User).where(User.phone_number == body.phone_number, User.role == RoleEnum.CUSTOMER)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(404, "No account found for this number. Ask your milkman to register you.")
    if not user.is_active:
        raise HTTPException(403, "Account suspended")

    if user.device_id is None:
        # First login ever - claim this device.
        user.device_id = body.device_id
        await db.commit()
    elif user.device_id != body.device_id:
        raise HTTPException(
            403,
            "This number is already logged in on another device. Ask your milkman to reset it.",
        )

    return _issue_token(user)
