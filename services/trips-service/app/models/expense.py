from sqlalchemy import Column, DateTime, ForeignKey, Integer, Numeric, String, func

from app.db.base import Base


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    stage_id = Column(Integer, ForeignKey("stages.id", ondelete="CASCADE"), nullable=True, index=True)
    description = Column(String(255), nullable=False)
    amount_rub = Column(Numeric(12, 2), nullable=False)
    category = Column(String(32), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
