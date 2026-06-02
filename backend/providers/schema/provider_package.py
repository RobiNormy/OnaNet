from uuid import UUID
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

    model_config = ConfigDict(
        from_attributes=True
    )