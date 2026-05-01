"""add planned_days to trips

Revision ID: 0005_add_planned_days
Revises: 0004_merge_trips_heads
Create Date: 2026-05-01 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_add_planned_days"
down_revision = "0004_merge_trips_heads"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("trips", sa.Column("planned_days", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("trips", "planned_days")

