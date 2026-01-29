"""initial

Revision ID: 0001_initial
Revises: 
Create Date: 2026-01-29 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
    )
    op.create_index("ix_trips_user_id", "trips", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_trips_user_id", table_name="trips")
    op.drop_table("trips")
