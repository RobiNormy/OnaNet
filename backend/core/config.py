from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    FIREBASE_SERVICE_ACCOUNT_PATH: str
    FIREBASE_API_KEY: str
    FIREBASE_PROJECT_ID: str | None = None

    SMS_PROVIDER: str = "console"
    DEV_OTP: str | None = None
    AT_USERNAME: str | None = None
    AT_API_KEY: str | None = None
    AT_SENDER_ID: str | None = None
    OTP_LENGTH: int = 6
    OTP_TTL_SECONDS: int = Field(300, env="OTP_TTL_sECONDS")
    OTP_MAX_ATTEMPTS: int = Field(5, env="OTP_MAX_aTTEMPTS")
    OTP_RATE_LIMIT_PER_HOUR: int = 3
    

    @property
    def database_url(self) -> str:
        return self.DATABASE_URL

    @property
    def supabase_url(self) -> str:
        return self.SUPABASE_URL

    @property
    def supabase_service_role_key(self) -> str:
        return self.SUPABASE_SERVICE_ROLE_KEY

    @property
    def firebase_service_account_path(self) -> str:
        return self.FIREBASE_SERVICE_ACCOUNT_PATH

    @property
    def firebase_project_id(self) -> str | None:
        return self.FIREBASE_PROJECT_ID

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()


@lru_cache
def get_settings() -> Settings:
    return settings
