from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ProviderCoverageAreaCreate(BaseModel):
    area_name: str = Field(..., min_length=2)
    latitude: float
    longitude: float
    radius_km: float = Field(default=3, ge=1, le=50)


class ProviderCoverageAreasCreate(BaseModel):
    coverage_areas: list[ProviderCoverageAreaCreate] = Field(..., min_length=1)


class ProviderCoverageAreaOut(BaseModel):
    id: UUID
    provider_id: UUID
    area_name: str
    latitude: float
    longitude: float
    radius_km: float

    model_config = ConfigDict(from_attributes=True)
