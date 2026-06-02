from uuid import UUID
from typing import List

from pydantic import BaseModel, ConfigDict, field_validator


class ProviderServicesCreate(BaseModel):
    service_types: List[str]

    @field_validator("service_types")
    @classmethod
    def clean_service_types(cls, value: list[str]) -> list[str]:
        cleaned = []
        seen = set()
        for service_type in value:
            normalized = service_type.strip()
            if normalized and normalized not in seen:
                cleaned.append(normalized)
                seen.add(normalized)

        if not cleaned:
            raise ValueError("Select at least one service")
        return cleaned


class ProviderServiceOut(BaseModel):
    id: UUID
    provider_id: UUID
    service_type: str

    model_config = ConfigDict(from_attributes=True)
