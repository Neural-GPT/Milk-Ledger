"""
Run this once, locally, to create (or reset) the admin account.
There is deliberately no HTTP endpoint for this - only someone with
direct access to the server/DB should be able to create an admin.

The admin logs in from the same screen as milkmen do, so the password
is kept numbers-only to match that field's numeric keyboard.

Usage:
    cd backend
    python -m scripts.create_admin
"""
import asyncio
import getpass

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import hash_value
from app.models.models import User, RoleEnum


def _prompt_numeric_password() -> str:
    while True:
        password = getpass.getpass("Choose an admin password (numbers only): ").strip()
        if not password.isdigit():
            print("Password must contain digits only. Try again.")
            continue
        confirm = getpass.getpass("Confirm password: ").strip()
        if password != confirm:
            print("Passwords do not match. Try again.")
            continue
        return password


async def main():
    username = input("Choose an admin username: ").strip()
    password = _prompt_numeric_password()

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.username == username))
        existing = result.scalar_one_or_none()

        if existing:
            existing.password_hash = hash_value(password)
            existing.is_active = True
            print(f"Password updated for existing admin '{username}'.")
        else:
            db.add(User(
                username=username,
                password_hash=hash_value(password),
                role=RoleEnum.ADMIN,
                is_active=True,
            ))
            print(f"Admin '{username}' created.")

        await db.commit()


if __name__ == "__main__":
    asyncio.run(main())
