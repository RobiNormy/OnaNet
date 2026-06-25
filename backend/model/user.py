from sqlalchemy import Column,String,Boolean
from sqlalchemy.dialects.postgresql import UUID
from backend.db.base import Base
import uuid
from sqlalchemy.sql import func
from sqlalchemy import DateTime

class User(Base):
    __tablename__ = "users"
    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4
    )
    firebase_uid = Column(
        String, unique=True, nullable=False
    )
    email = Column(String, unique=True,nullable=False)
    first_name = Column(String,nullable=True)
    last_name = Column(String,nullable=True)
    phone_number = Column(String,nullable=True)
    profile_image_url = Column(String, nullable=True)
    auth_provider = Column(String,default="email")
    role = Column(String, default="user", nullable=False)
    is_phone_verified = Column(Boolean,default=False)
    is_profile_complete = Column(Boolean,default=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now()
        )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )

    
