"""add place image url

Revision ID: 0002_place_image_url
Revises: 0001_initial
Create Date: 2026-03-27
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_place_image_url"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("places", sa.Column("image_url", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("places", "image_url")
