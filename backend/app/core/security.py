import random
from datetime import datetime, timedelta, timezone

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


def hash_value(value: str) -> str:
    return pwd_context.hash(value)


def verify_value(value: str, hashed: str) -> bool:
    return pwd_context.verify(value, hashed)


def generate_otp() -> str:
    return "".join(random.choices("0123456789", k=settings.otp_length))


def utc_now() -> datetime:
    """Always timezone-aware, to match DateTime(timezone=True) columns."""
    return datetime.now(timezone.utc)


def create_access_token(*, subject: str, role: str) -> str:
    expire = utc_now() + timedelta(minutes=settings.jwt_access_token_expire_minutes)
    payload = {"sub": subject, "role": role, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
