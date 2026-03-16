from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, Numeric, String, Text, func

from app.db.base import Base


class Stage(Base):
    __tablename__ = "stages"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    position = Column(Integer, nullable=False, index=True)

    stage_type = Column(String(32), nullable=False, index=True)
    subtype = Column(String(64), nullable=False, index=True)
    title = Column(String(255), nullable=False)

    start_location = Column(String(255), nullable=True)
    end_location = Column(String(255), nullable=True)
    address = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    start_time = Column(DateTime(timezone=True), nullable=True)
    end_time = Column(DateTime(timezone=True), nullable=True)
    duration_minutes = Column(Integer, nullable=True)
    cost_rub = Column(Numeric(12, 2), nullable=True)
    reference_number = Column(String(128), nullable=True)
    website_url = Column(String(512), nullable=True)
    rating = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    document_key = Column(String(512), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
