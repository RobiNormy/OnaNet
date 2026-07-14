from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from backend.model.user import User
class UserRepository:
    def __init__(self,session:AsyncSession):
        self.session = session

    async def get_by_firebase_uid(self,firebase_uid:str)-> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.firebase_uid == firebase_uid)
        )
        return result.scalar_one_or_none()
    
    async def get_by_email(self,email:str)-> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.email == email.strip().lower())
        )
        return result.scalar_one_or_none()
    
    async def get_by_id(self,user_id:UUID)->Optional[User]:
        result = await self.session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()
    
    async def create(self, data: dict) -> User:
        if "email" in data and data["email"]:
            data["email"] = data["email"].strip().lower()

        user = User(**data)
        self.session.add(user)

        await self.session.commit()
        await self.session.refresh(user)

        return user

    async def update(self, user_id: UUID, data: dict) -> Optional[User]:
        user = await self.get_by_id(user_id)

        if not user:
            return None

        if "email" in data and data["email"]:
            data["email"] = data["email"].strip().lower()

        for key, value in data.items():
            if hasattr(user, key):
                setattr(user, key, value)

        await self.session.commit()
        await self.session.refresh(user)

        return user

    
