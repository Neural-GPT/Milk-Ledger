from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


def _build_engine():
    """
    Aiven (and most managed Postgres providers) hand you a URL with
    ?sslmode=require - that's psycopg/libpq syntax, and asyncpg doesn't
    understand it (it'll crash with "unexpected keyword argument
    'sslmode'"). We strip that query param and pass the SSL requirement
    to asyncpg the way it actually expects: via connect_args.

    SQLite doesn't take an `ssl` connect arg at all, so this only
    applies when the URL is actually using the asyncpg driver.
    """
    url = make_url(settings.database_url)
    connect_args = {}

    if url.drivername.startswith("postgresql"):
        query = dict(url.query)
        query.pop("sslmode", None)  # asyncpg doesn't accept this key
        url = url.set(query=query)
        connect_args["ssl"] = "require"

    return create_async_engine(
        url,
        echo=(settings.env == "development"),
        connect_args=connect_args,
    )


engine = _build_engine()
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session