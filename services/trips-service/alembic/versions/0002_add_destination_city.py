"""add destination city to trips

Revision ID: 0002_add_destination_city
Revises: 0001_initial
Create Date: 2026-04-19 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_add_destination_city"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("trips", sa.Column("destination_city", sa.String(length=128), nullable=True))


def downgrade() -> None:
    op.drop_column("trips", "destination_city")
