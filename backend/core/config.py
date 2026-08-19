from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_PUBLISHABLE_KEY: str | None = None
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    GEOAPIFY_API_KEY: str | None = None

    GAVACONNECT_CONSUMER_KEY: str | None = None
    GAVACONNECT_CONSUMER_SECRET: str | None = None
    GAVACONNECT_ENV: str = "sandbox"

    SMS_PROVIDER: str = "console"
    DEV_OTP: str | None = None
    AT_USERNAME: str | None = None
    AT_API_KEY: str | None = None
    AT_SENDER_ID: str | None = None
    OTP_LENGTH: int = 6
    OTP_TTL_SECONDS: int = Field(300, env="OTP_TTL_sECONDS")
    OTP_MAX_ATTEMPTS: int = Field(5, env="OTP_MAX_aTTEMPTS")
    OTP_RATE_LIMIT_PER_HOUR: int = 3

    PAYSTACK_SECRET_KEY: str | None = None
    PAYSTACK_PUBLIC_KEY: str | None = None
    PAYSTACK_CALLBACK_URL: str | None = None
    PAYSTACK_GROWTH_PLAN_CODE: str | None = None
    PAYSTACK_PRO_PLAN_CODE: str | None = None
    PAYSTACK_GROWTH_KEY: str | None = None
    PAYSTACK_PRO_KEY: str | None = None
    PAYSTACK_GROWTH_AMOUNT_KES: int = 3000
    PAYSTACK_PRO_AMOUNT_KES: int = 5000

    RESEND_API_KEY: str | None = None
    RESEND_WEBHOOK_SECRET: str | None = None
    RESEND_FROM_EMAIL: str = "OnaNet <hello@mail.onanet.app>"
    RESEND_SECURITY_FROM_EMAIL: str = (
        "OnaNet Security <no-reply@mail.onanet.app>"
    )
    RESEND_SUPPORT_FROM_EMAIL: str = "OnaNet Support <support@mail.onanet.app>"
    RESEND_REPLY_TO: str | None = "support@mail.onanet.app"

    @property
    def database_url(self) -> str:
        return self.DATABASE_URL

    @property
    def supabase_url(self) -> str:
        return self.SUPABASE_URL

    @property
    def supabase_service_role_key(self) -> str:
        return self.SUPABASE_SERVICE_ROLE_KEY

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()


@lru_cache
def get_settings() -> Settings:
    return settings
