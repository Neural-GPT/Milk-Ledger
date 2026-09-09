import enum
import uuid
from datetime import datetime, date, timezone

from sqlalchemy import (
    String, Boolean, ForeignKey, Numeric, Date, DateTime, Enum, JSON, Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def gen_uuid():
    return str(uuid.uuid4())


# Portable across SQLite (local dev) and PostgreSQL (Aiven/production) -
# both just store this as a 36-char string, no dialect-specific type needed.
UUIDStr = String(36)


class RoleEnum(str, enum.Enum):
    ADMIN = "ADMIN"
    MILKMAN = "MILKMAN"
    CUSTOMER = "CUSTOMER"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    # CUSTOMER login identifier - phone number only, no password/OTP.
    phone_number: Mapped[str | None] = mapped_column(String(15), unique=True, index=True, nullable=True)
    # ADMIN and MILKMAN login identifier - username + password, issued by admin.
    username: Mapped[str | None] = mapped_column(String(50), unique=True, index=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # CUSTOMER device lock: set on first successful login, then that phone
    # number can only ever log in again from the same device.
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role: Mapped[RoleEnum] = mapped_column(Enum(RoleEnum), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )


class Milkman(Base):
    __tablename__ = "milkmen"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    name: Mapped[str] = mapped_column(String(120))
    phone_number: Mapped[str] = mapped_column(String(15))
    business_name: Mapped[str | None] = mapped_column(String(150), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    customers: Mapped[list["Customer"]] = relationship(back_populates="milkman")


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    milkman_id: Mapped[str] = mapped_column(ForeignKey("milkmen.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    phone_number: Mapped[str] = mapped_column(String(15))
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    milkman: Mapped["Milkman"] = relationship(back_populates="customers")


class MilkPrice(Base):
    """Price history so historical bills never change when today's price changes (Rule 3/4)."""
    __tablename__ = "milk_prices"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    milkman_id: Mapped[str] = mapped_column(ForeignKey("milkmen.id"), index=True)
    price_per_litre: Mapped[float] = mapped_column(Numeric(10, 2))
    effective_from: Mapped[date] = mapped_column(Date)
    effective_until: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class MilkEntry(Base):
    __tablename__ = "milk_entries"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    customer_id: Mapped[str] = mapped_column(ForeignKey("customers.id"), index=True)
    milkman_id: Mapped[str] = mapped_column(ForeignKey("milkmen.id"), index=True)
    delivery_date: Mapped[date] = mapped_column(Date, index=True)
    quantity_litres: Mapped[float] = mapped_column(Numeric(6, 2))
    price_per_litre: Mapped[float] = mapped_column(Numeric(10, 2))
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2))
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)  # soft delete (Rule 8)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id"))


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(150))
    message: Mapped[str] = mapped_column(Text)
    type: Mapped[str] = mapped_column(String(50))  # e.g. MILK_ENTRY_CREATED
    reference_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class AuditLog(Base):
    """
    Every logged entry / value change in the system lands here.
    Visibility is enforced in the API layer (see app/services/audit.py),
    NOT by giving broad table access - a customer's query is always
    filtered down to entity_id's belonging to them.
    """
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(UUIDStr, primary_key=True, default=gen_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)  # who performed the action
    action: Mapped[str] = mapped_column(String(50), index=True)  # MILK_ENTRY_CREATED, PRICE_CHANGED, ...
    entity_type: Mapped[str] = mapped_column(String(50), index=True)  # milk_entry, customer, price
    entity_id: Mapped[str] = mapped_column(String(100), index=True)
    customer_id: Mapped[str | None] = mapped_column(ForeignKey("customers.id"), nullable=True, index=True)
    milkman_id: Mapped[str | None] = mapped_column(ForeignKey("milkmen.id"), nullable=True, index=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # {"old": ..., "new": ...}
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)
