from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session


class UserRepository:
    """Database operations for users."""

    def __init__(self, db: Session, model: type[Any] | None = None) -> None:
        self.db = db
        self.model = model or self._load_user_model()

    @staticmethod
    def _load_user_model() -> type[Any]:
        try:
            from backend.model.user import User
        except ImportError as exc:
            raise RuntimeError("backend.model.user.User must be defined first") from exc

        return User

    def get_by_id(self, user_id: Any) -> Any | None:
        return self.db.get(self.model, user_id)

    def get_by_email(self, email: str) -> Any | None:
        normalized_email = self._normalize_email(email)
        stmt = select(self.model).where(self.model.email == normalized_email)
        return self.db.execute(stmt).scalar_one_or_none()

    def get_by_firebase_uid(self, firebase_uid: str) -> Any | None:
        stmt = select(self.model).where(self.model.firebase_uid == firebase_uid)
        return self.db.execute(stmt).scalar_one_or_none()

    def list(self, *, skip: int = 0, limit: int = 100) -> list[Any]:
        stmt = select(self.model).offset(skip).limit(limit)
        return list(self.db.execute(stmt).scalars().all())

    def create(self, user_in: Any, **extra_fields: Any) -> Any:
        data = self._to_dict(user_in)
        data.update(extra_fields)

        if "email" in data and data["email"] is not None:
            data["email"] = self._normalize_email(data["email"])

        db_user = self.model(**data)
        return self._save(db_user)

    def update(self, db_user: Any, user_in: Any | None = None, **changes: Any) -> Any:
        data = self._to_dict(user_in, exclude_unset=True) if user_in is not None else {}
        data.update(changes)

        if "email" in data and data["email"] is not None:
            data["email"] = self._normalize_email(data["email"])

        for field, value in data.items():
            if hasattr(db_user, field):
                setattr(db_user, field, value)

        return self._save(db_user)

    def delete(self, db_user: Any) -> None:
        try:
            self.db.delete(db_user)
            self.db.commit()
        except SQLAlchemyError:
            self.db.rollback()
            raise

    def delete_by_id(self, user_id: Any) -> bool:
        db_user = self.get_by_id(user_id)
        if db_user is None:
            return False

        self.delete(db_user)
        return True

    def exists(self, *, email: str | None = None, firebase_uid: str | None = None) -> bool:
        if email is None and firebase_uid is None:
            raise ValueError("Provide email or firebase_uid")

        if email is not None:
            return self.get_by_email(email) is not None

        return self.get_by_firebase_uid(firebase_uid or "") is not None

    def _save(self, db_user: Any) -> Any:
        try:
            self.db.add(db_user)
            self.db.commit()
            self.db.refresh(db_user)
        except SQLAlchemyError:
            self.db.rollback()
            raise

        return db_user

    @staticmethod
    def _to_dict(data: Any, *, exclude_unset: bool = False) -> dict[str, Any]:
        if data is None:
            return {}

        if isinstance(data, Mapping):
            return dict(data)

        if hasattr(data, "model_dump"):
            return data.model_dump(exclude_unset=exclude_unset, exclude_none=True)

        if hasattr(data, "dict"):
            return data.dict(exclude_unset=exclude_unset, exclude_none=True)

        raise TypeError("Expected a mapping or Pydantic-style schema object")

    @staticmethod
    def _normalize_email(email: str) -> str:
        return email.strip().lower()


UserRepo = UserRepository
