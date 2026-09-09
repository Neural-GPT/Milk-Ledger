from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    All values are read from environment variables (.env).
    Nothing here is hardcoded, so plugging in your Aiven DB
    credentials later is just a matter of filling in .env.
    """

    database_url: str = "postgresql+asyncpg://USER:PASSWORD@HOST:PORT/DBNAME"

    jwt_secret: str = "change_me_to_a_long_random_string"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 1440

    sms_gateway_provider: str = "msg91"
    sms_gateway_api_key: str = ""
    sms_gateway_sender_id: str = "MILKAP"

    otp_expire_minutes: int = 5
    otp_length: int = 6

    env: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()
