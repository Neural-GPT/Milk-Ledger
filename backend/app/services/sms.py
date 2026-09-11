"""
Sends real SMS via TextBee (an Android phone running the TextBee app,
acting as an SMS gateway - see textbee.dev). Used to reach a customer
even when they don't have the app open.

If TEXTBEE_API_KEY / TEXTBEE_DEVICE_ID aren't set in .env, this quietly
does nothing - the in-app notification still gets created either way,
so nothing breaks in local dev without a TextBee device configured.
"""
import httpx

from app.core.config import settings


def _normalize_phone(phone_number: str) -> str:
    """TextBee expects full international format, e.g. +919876543210."""
    phone_number = phone_number.strip()
    if phone_number.startswith("+"):
        return phone_number
    return f"{settings.default_country_code}{phone_number}"


async def send_sms(phone_number: str, message: str) -> bool:
    if not settings.textbee_api_key or not settings.textbee_device_id:
        return False

    url = f"https://api.textbee.dev/api/v1/gateway/devices/{settings.textbee_device_id}/send-sms"

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                url,
                json={"recipients": [_normalize_phone(phone_number)], "message": message},
                headers={"x-api-key": settings.textbee_api_key, "Content-Type": "application/json"},
            )
            response.raise_for_status()
            return True
    except Exception:
        # SMS is a best-effort add-on to the in-app notification, never
        # something that should break the actual milk-entry flow.
        return False
