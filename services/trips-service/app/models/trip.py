from sqlalchemy import Column, Integer, String, Date, Boolean

from app.db.base import Base


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(String(500), nullable=True)
    destination_city = Column(String(128), nullable=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    planned_days = Column(Integer, nullable=True)
    card_color = Column(String(16), nullable=True)
    card_background = Column(String(32), nullable=True)
    card_icon = Column(String(32), nullable=True)
    is_archived = Column(Boolean, nullable=False, default=False)
    user_id = Column(Integer, nullable=False)
