import uuid

from sqlalchemy import Column, DateTime, ForeignKey, Float, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from backend.db.base import Base


class ProviderCoverageArea(Base):
    __tablename__ = "provider_coverage_areas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    provider_id = Column(
        UUID(as_uuid=True),
        ForeignKey("providers.id", ondelete="CASCADE"),
        nullable=False,
    )

    area_name = Column(String, nullable=False)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    radius_km = Column(Numeric, default=3)

    created_at = Column(DateTime(timezone=True), server_default=func.now())