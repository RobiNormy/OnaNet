import uuid

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String
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
        unique=True,
    )

    support_email = Column(String, nullable=True)
    support_phone = Column(String, nullable=True)
    website_url = Column(String, nullable=True)
    social_url = Column(String, nullable=True)

    is_phone_verified = Column(Boolean, default=False)
    is_email_verified = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )