from __future__ import annotations

from datetime import date, datetime, time

from typing import Literal

from uuid import UUID

from pydantic import BaseModel,Field

class InstallationRequestCreate(BaseModel):
    provider_id: UUID
    package_id: UUID
    phone_e164: str = Field(...,min_length=8,max_length=20)

    gps_location:str | None = None
    estate_or_building: str = Field(...,min_length=1,max_length=200)
    house_or_apartment: str | None = Field(default=None,max_length=120)
    landmark: str | None = Field(default=None,max_length=500)

    preferred_date: date
    preferred_time: time


InstallationStatus = Literal[
    "pending",
    "accepted",
    "declined",
    "completed",
]

class InstallationRequestOut(BaseModel):
    id:UUID
    user_id:UUID
    provider_id:UUID
    package_id:UUID

    phone_e164: str
    gps_location: str | None = Field(default=None)

    estate_or_building: str
    house_or_apartment: str | None = Field(default=None)
    landmark:str | None = Field(default=None)
    gps_location: str | None = None

    estate_or_building: str
    house_or_apartment: str
    landmark:str | None = None

    preferred_date: date
    preferred_time: time

    status: InstallationStatus
    decline_reason: str | None = Field(default=None)
    completed_at: datetime | None = Field(default=None)

    decline_reason: str | None = None
    completed_at: datetime | None = None
    
    created_at: datetime
    updated_at: datetime
    
