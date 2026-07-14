from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from backend.db.base import Base
import uuid


class Provider(Base):
    __tablename__ = "providers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    provider_type = Column(String, nullable=False)

    provider_name = Column(String, nullable=False)
    business_name = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)

    primary_city = Column(String, nullable=True)

    year_started = Column(Integer, nullable=True)
    description = Column(Text, nullable=True)

    status = Column(String, default="draft")
    is_verified = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())