"""add expenses table

Revision ID: 0002_expenses
Revises: 0001_initial
Create Date: 2026-03-15 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_expenses"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "expenses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=False),
        sa.Column("amount_rub", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_expenses_trip_id", "expenses", ["trip_id"])
    op.create_index("ix_expenses_category", "expenses", ["category"])


def downgrade() -> None:
    op.drop_index("ix_expenses_category", table_name="expenses")
    op.drop_index("ix_expenses_trip_id", table_name="expenses")
    op.drop_table("expenses")
