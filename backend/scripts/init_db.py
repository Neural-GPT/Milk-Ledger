"""
Creates all tables directly from the SQLAlchemy models against whatever
DATABASE_URL is in .env. Fine for MVP speed on a local/dev DB.

Once this app has real user data on Aiven, switch to Alembic migrations
instead of running this again (it won't drop/alter existing tables, but
proper migrations give you version history and safe rollbacks).

Usage:
    cd backend
    python -m scripts.init_db
"""
import asyncio

from app.core.database import engine, Base
from app.models import models  # noqa: F401 - ensures models are registered on Base


async def main():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tables created (or already existed).")


if __name__ == "__main__":
    asyncio.run(main())
