"""merge trips migration heads

Revision ID: 0004_merge_trips_heads
Revises: 0002_add_destination_city, 0003_stages
Create Date: 2026-04-23 00:00:00.000000
"""

revision = "0004_merge_trips_heads"
down_revision = ("0002_add_destination_city", "0003_stages")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
