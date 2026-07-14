from uuid import UUID
from typing import Any

from pydantic import BaseModel, ConfigDict

class ProviderPackageCreate(BaseModel):
    package_name: str
    speed_mbps: int
    monthly_price: float
    installation_fee: float = 0
    fair_usage_policy: str | None = None
    billing_cycle: str = "monthly"
    contract_type: str = "no_contract"
    installation_period: str | None = None
    router_included: bool = False


class ProviderPackageUpdate(BaseModel):
    package_name: str | None = None
    speed_mbps: int | None = None
    monthly_price: float | None = None
    installation_fee: float | None = None
    fair_usage_policy: str | None = None
    billing_cycle: str | None = None
    contract_type: str | None = None
    installation_period: str | None = None
    router_included: bool | None = None


class ProviderPackageOut(BaseModel):
    id: UUID
    provider_id: UUID

    package_name: str
    speed_mbps: int
    monthly_price: float
    installation_fee: float

    fair_usage_policy: str | None
    billing_cycle: str
    contract_type: str
    installation_period: str | None

    router_included: bool
    trust_label: str | None = None
    subscriber_count: str | None = None
    popular: bool = False
    top_area: str | None = None
    popularity_level: str | None = None
    popularity_by_area: list[dict[str, Any]] = []

    model_config = ConfigDict(
        from_attributes=True
    )
