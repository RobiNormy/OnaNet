from pydantic import BaseModel, ConfigDict, field_validator
from uuid import UUID
from typing import Any, Literal, Optional


class ProviderCreate(BaseModel):
    provider_type: str
    provider_name: str
    business_name: Optional[str] = None
    primary_city: Optional[str] = None
    year_started: Optional[int] = None
    description: Optional[str] = None


class ProviderOut(ProviderCreate):
    id: UUID
    user_id: UUID
    status: str
    is_verified: bool

    model_config = ConfigDict(from_attributes=True)


class ProviderRegistrationRequest(BaseModel):
    provider_type: Literal["local_provider"]
    provider_name: str
    business_name: str | None = None
    logo_url: str | None = None
    logo_display_size: float = 1.0
    logo_offset_x: float = 0.0
    logo_offset_y: float = 0.0
    year_started: int | None = None
    upstream_provider: str | None = None
    primary_city: str
    description: str | None = None

    @field_validator("provider_name", "primary_city", mode="before")
    @classmethod
    def clean_required_string(cls, value: Any) -> str:
        if value is None or not str(value).strip():
            raise ValueError("Required")
        return str(value).strip()

    @field_validator(
        "business_name",
        "logo_url",
        "upstream_provider",
        "description",
        mode="before",
    )
    @classmethod
    def clean_optional_string(cls, value: Any) -> str | None:
        if value is None:
            return None
        return str(value).strip() or None

    @field_validator("year_started")
    @classmethod
    def validate_year_started(cls, value: int | None) -> int | None:
        if value is not None and value < 1900:
            raise ValueError("Year started is too old")
        return value


class ProviderRegistrationResponse(BaseModel):
    id: str
    user_id: str
    provider_type: Literal["local_provider"]
    provider_name: str
    business_name: str | None = None
    logo_url: str | None = None
    logo_display_size: float = 1.0
    logo_offset_x: float = 0.0
    logo_offset_y: float = 0.0
    year_started: int | None = None
    upstream_provider: str | None = None
    primary_city: str | None = None
    description: str | None = None
    status: str
    is_verified: bool = False
    subscription_tier: str = "free"
    created_at: str | None = None
    updated_at: str | None = None
