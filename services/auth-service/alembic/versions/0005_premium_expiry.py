"""add premium expiry

Revision ID: 0005_premium_expiry
Revises: 0004_premium_flag
Create Date: 2026-05-13
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_premium_expiry"
down_revision = "0004_premium_flag"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "premium_expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "premium_expires_at")
