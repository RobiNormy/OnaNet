from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import List


class ProviderServicesCreate(BaseModel):
    service_types: List[str]


class ProviderServiceOut(BaseModel):
    id: UUID
    provider_id: UUID
    service_type: str

    model_config = ConfigDict(from_attributes=True) 