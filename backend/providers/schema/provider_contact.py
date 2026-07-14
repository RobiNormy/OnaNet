from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


ContactType = Literal["email", "phone", "website", "social"]


class ProviderContactCreate(BaseModel):
    contact_type: ContactType
    contact_value: str = Field(..., min_length=2)
    social_platform: str | None = None

    @field_validator("contact_value", "social_platform", mode="before")
    @classmethod
    def clean_optional_string(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return str(value).strip() or None


class ProviderContactsCreate(BaseModel):
    contacts: list[ProviderContactCreate] = Field(default_factory=list)


class ProviderContactOut(BaseModel):
    id: UUID
    provider_id: UUID
    contact_type: str
    contact_value: str
    social_platform: str | None = None

    model_config = ConfigDict(from_attributes=True)
