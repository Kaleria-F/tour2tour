"""add place story image source

Revision ID: 0005_place_story_image_source
Revises: 0004_place_image_source
Create Date: 2026-05-13 23:15:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_place_story_image_source"
down_revision = "0004_place_image_source"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("place_stories", sa.Column("image_source", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("place_stories", "image_source")
