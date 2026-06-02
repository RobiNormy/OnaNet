import uuid

from sqlalchemy import Column, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from backend.db.base import Base


class ProviderContact(Base):
    __tablename__ = "provider_contacts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    provider_id = Column(
        UUID(as_uuid=True),
        ForeignKey("providers.id", ondelete="CASCADE"),
        nullable=False,
    )

    contact_type = Column(String, nullable=False)
    contact_value = Column(String, nullable=False)
    social_platform = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
