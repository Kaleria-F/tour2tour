"""add place stories

Revision ID: 0003_place_stories
Revises: 0002_place_image_url
Create Date: 2026-04-24
"""

from alembic import op
import sqlalchemy as sa

revision = "0003_place_stories"
down_revision = "0002_place_image_url"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "place_stories",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("title", sa.String(length=140), nullable=False),
        sa.Column("cover_image_url", sa.String(length=512), nullable=True),
        sa.Column("image_url", sa.String(length=512), nullable=False),
        sa.Column("body_text", sa.Text(), nullable=True),
        sa.Column("place_id", sa.String(length=36), sa.ForeignKey("places.id", ondelete="SET NULL"), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_place_stories_place_id", "place_stories", ["place_id"])
    op.create_index("ix_place_stories_is_active", "place_stories", ["is_active"])


def downgrade() -> None:
    op.drop_index("ix_place_stories_is_active", table_name="place_stories")
    op.drop_index("ix_place_stories_place_id", table_name="place_stories")
    op.drop_table("place_stories")
