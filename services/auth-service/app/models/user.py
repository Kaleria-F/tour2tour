from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), default="traveler")  # traveler/admin
    is_2fa_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    preferences = relationship(
        "UserPreference",
        back_populates="user",
        cascade="all, delete-orphan",
    )
