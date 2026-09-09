from fastapi import FastAPI

from app.routers import auth, customers, milk_entries, prices, notifications, audit, admin, dashboard

app = FastAPI(title="Milk Delivery Management API", version="0.1.0-mvp")

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(customers.router)
app.include_router(milk_entries.router)
app.include_router(prices.router)
app.include_router(notifications.router)
app.include_router(audit.router)
app.include_router(dashboard.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
