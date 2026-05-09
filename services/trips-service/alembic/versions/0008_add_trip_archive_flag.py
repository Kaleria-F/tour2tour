"""add trip archive flag

Revision ID: 0008_add_trip_archive_flag
Revises: 0007_add_trip_card_customization
Create Date: 2026-05-09 20:05:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0008_add_trip_archive_flag"
down_revision = "0007_add_trip_card_customization"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "trips",
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.alter_column("trips", "is_archived", server_default=None)


def downgrade() -> None:
    op.drop_column("trips", "is_archived")

