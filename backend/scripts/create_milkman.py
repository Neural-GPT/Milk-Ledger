"""
Creates a milkman account directly in the DB - same effect as the admin
using POST /admin/milkmen, just faster for local testing.

The milkman logs in with just their name + phone number (no password) -
see /auth/milkman-login.

Usage:
    cd backend
    python -m scripts.create_milkman
"""
import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.models.models import User, Milkman, RoleEnum


async def main():
    name = input("Milkman name: ").strip()
    phone_number = input("Milkman phone number: ").strip()
    business_name = input("Business name (optional, press Enter to skip): ").strip() or None

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(User).where(User.phone_number == phone_number))
        if existing.scalar_one_or_none():
            print(f"Phone number '{phone_number}' is already registered. Aborting.")
            return

        user = User(phone_number=phone_number, role=RoleEnum.MILKMAN, is_active=True)
        db.add(user)
        await db.flush()

        db.add(Milkman(
            user_id=user.id,
            name=name,
            phone_number=phone_number,
            business_name=business_name,
        ))

        await db.commit()
        print(f"Milkman '{name}' created.")
        print(f"They log in with name='{name}' and phone_number='{phone_number}' via /auth/milkman-login.")


if __name__ == "__main__":
    asyncio.run(main())
