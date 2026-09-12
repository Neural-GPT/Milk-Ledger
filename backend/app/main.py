import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.routers import auth, customers, milk_entries, prices, notifications, audit, admin, dashboard, feedback
from app.core.database import engine

logger = logging.getLogger("milk_app")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="Milk Delivery Management API", version="0.1.0-mvp")

# The Flutter app talks to this over HTTPS from a phone, not a browser,
# so CORS isn't strictly required - but it's harmless to allow, and
# means a future web admin panel or manual API testing from a browser
# just works without a separate change.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(customers.router)
app.include_router(milk_entries.router)
app.include_router(prices.router)
app.include_router(notifications.router)
app.include_router(audit.router)
app.include_router(dashboard.router)
app.include_router(feedback.router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """
    In production, an unhandled error should never leak a Python
    traceback to the client - log it server-side (visible in Render's
    logs) and return a clean, generic JSON error instead.
    """
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong on our end. Please try again in a moment."},
    )


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
