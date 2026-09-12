from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    All values are read from environment variables (.env).
    Nothing here is hardcoded, so plugging in your Aiven DB
    credentials later is just a matter of filling in .env.
    """

    database_url: str = "sqlite+aiosqlite:///./milk_delivery.db"

    jwt_secret: str = "change_me_to_a_long_random_string"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 1440

    env: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()
