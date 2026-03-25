"""initial

Revision ID: 0001_initial
Revises:
Create Date: 2026-03-20
"""

from alembic import op
import sqlalchemy as sa

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_place_interactions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("place_id", sa.String(length=64), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("context", sa.String(length=32), nullable=False, server_default="recommendation"),
        sa.Column("session_id", sa.String(length=64), nullable=True),
        sa.Column("recommendation_id", sa.String(length=64), nullable=True),
        sa.Column("weight", sa.Float(), nullable=False, server_default="1"),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_user_place_interactions_user_id", "user_place_interactions", ["user_id"])
    op.create_index("ix_user_place_interactions_place_id", "user_place_interactions", ["place_id"])
    op.create_index("ix_user_place_interactions_action", "user_place_interactions", ["action"])
    op.create_index("ix_user_place_interactions_created_at", "user_place_interactions", ["created_at"])

    op.create_table(
        "recommendation_impressions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("place_id", sa.String(length=64), nullable=False),
        sa.Column("recommendation_id", sa.String(length=64), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("context", sa.String(length=32), nullable=False, server_default="recommendation"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_recommendation_impressions_user_id", "recommendation_impressions", ["user_id"])
    op.create_index("ix_recommendation_impressions_place_id", "recommendation_impressions", ["place_id"])
    op.create_index("ix_recommendation_impressions_recommendation_id", "recommendation_impressions", ["recommendation_id"])


def downgrade() -> None:
    op.drop_index("ix_recommendation_impressions_recommendation_id", table_name="recommendation_impressions")
    op.drop_index("ix_recommendation_impressions_place_id", table_name="recommendation_impressions")
    op.drop_index("ix_recommendation_impressions_user_id", table_name="recommendation_impressions")
    op.drop_table("recommendation_impressions")
    op.drop_index("ix_user_place_interactions_created_at", table_name="user_place_interactions")
    op.drop_index("ix_user_place_interactions_action", table_name="user_place_interactions")
    op.drop_index("ix_user_place_interactions_place_id", table_name="user_place_interactions")
    op.drop_index("ix_user_place_interactions_user_id", table_name="user_place_interactions")
    op.drop_table("user_place_interactions")
