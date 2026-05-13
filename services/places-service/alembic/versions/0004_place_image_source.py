"""add place image source

Revision ID: 0004_place_image_source
Revises: 0003_place_stories
Create Date: 2026-05-13 22:40:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0004_place_image_source"
down_revision = "0003_place_stories"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("places", sa.Column("image_source", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("places", "image_source")
