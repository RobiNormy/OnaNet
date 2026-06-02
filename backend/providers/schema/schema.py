from typing import Any, Literal

from pydantic import BaseModel, field_validator


class ProviderRegistrationRequest(BaseModel):
    provider_type: Literal["licensed_isp", "local_provider"]
    provider_name: str
    business_name: str | None = None
    logo_url: str | None = None
    year_started: int | None = None
    primary_city: str
    description: str | None = None

    @field_validator(
        "provider_name",
        "primary_city",
        mode="before",
    )
    @classmethod
    def clean_required_string(cls, value: Any) -> str:
        if value is None:
            raise ValueError("Required")

        cleaned = str(value).strip()
        if not cleaned:
            raise ValueError("Required")
        return cleaned

    @field_validator(
        "business_name",
        "logo_url",
        "description",
        mode="before",
    )
    @classmethod
    def clean_optional_string(cls, value: Any) -> str | None:
        if value is None:
            return None

        cleaned = str(value).strip()
        return cleaned or None

    @field_validator("year_started")
    @classmethod
    def validate_year_started(cls, value: int | None) -> int | None:
        if value is None:
            return None
        if value < 1900:
            raise ValueError("Year started is too old")
        return value


class ProviderRegistrationResponse(BaseModel):
    id: str
    user_id: str
    provider_type: Literal["licensed_isp", "local_provider"]
    provider_name: str
    business_name: str | None = None
    logo_url: str | None = None
    year_started: int | None = None
    primary_city: str | None = None
    description: str | None = None
    status: str
    is_verified: bool = False
    created_at: str | None = None
    updated_at: str | None = None
