from fastapi import FastAPI
from sqlalchemy import text

from app.routers import auth, customers, milk_entries, prices, notifications, audit, admin, dashboard, feedback
from app.core.database import engine

app = FastAPI(title="Milk Delivery Management API", version="0.1.0-mvp")

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(customers.router)
app.include_router(milk_entries.router)
app.include_router(prices.router)
app.include_router(notifications.router)
app.include_router(audit.router)
app.include_router(dashboard.router)
app.include_router(feedback.router)


@app.get("/health")
async def health():
    """
    Checked by uptime pings (see README) to keep a free-tier Render
    instance from spinning down, and to confirm the DB connection is
    actually alive, not just that the process is running.
    """
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    return {"status": "ok" if db_ok else "degraded", "database": "connected" if db_ok else "unreachable"}
