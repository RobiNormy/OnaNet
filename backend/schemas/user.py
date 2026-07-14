from pydantic import BaseModel
from uuid import UUID
from typing import Optional
from pydantic import ConfigDict
class UserOut(BaseModel):
    id:UUID
    firebase_uid:str
    email: str
    first_name:Optional[str]=None
    last_name:Optional[str]=None
    phone_number:Optional[str]=None
    profile_image_url:Optional[str]=None
    auth_provider:str
    role: str
    is_phone_verified:bool
    is_profile_complete:bool

    model_config = ConfigDict(from_attributes=True)
    
class AuthResponse(BaseModel):
    access_token: str
    token_type:str = "bearer"
    user:UserOut
    