from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Float, ForeignKey, Integer, JSON, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Place(Base):
    __tablename__ = "places"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    external_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    source: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(24), default="approved")
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    country: Mapped[str | None] = mapped_column(String(64), nullable=True)
    city: Mapped[str] = mapped_column(String(128), index=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lon: Mapped[float | None] = mapped_column(Float, nullable=True)
    category: Mapped[str] = mapped_column(String(64), index=True)
    subcategory: Mapped[str | None] = mapped_column(String(64), nullable=True)
    price_level: Mapped[str | None] = mapped_column(String(24), nullable=True)
    avg_visit_duration_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rating: Mapped[float | None] = mapped_column(Float, nullable=True)
    reviews_count: Mapped[int] = mapped_column(Integer, default=0)
    working_hours_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    metadata_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    tags: Mapped[list["PlaceTag"]] = relationship(
        back_populates="place",
        cascade="all, delete-orphan",
    )


class PlaceTag(Base):
    __tablename__ = "place_tags"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    place_id: Mapped[str] = mapped_column(ForeignKey("places.id", ondelete="CASCADE"), index=True)
    tag: Mapped[str] = mapped_column(String(64), index=True)
    weight: Mapped[int] = mapped_column(Integer)

    place: Mapped[Place] = relationship(back_populates="tags")


class PlaceCandidate(Base):
    __tablename__ = "place_candidates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source: Mapped[str] = mapped_column(String(64), index=True)
    source_record_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    status: Mapped[str] = mapped_column(String(24), default="pending_review", index=True)
    payload_json: Mapped[dict[str, Any]] = mapped_column(JSON)
    normalized_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    validation_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class PlaceImportJob(Base):
    __tablename__ = "place_import_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source: Mapped[str] = mapped_column(String(64))
    kind: Mapped[str] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(24), default="created", index=True)
    file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    stats_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_by: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
