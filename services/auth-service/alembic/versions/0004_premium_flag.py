"""add premium flag

Revision ID: 0004_premium_flag
Revises: 0003_profile_fields
Create Date: 2026-05-07
"""

from alembic import op
import sqlalchemy as sa


revision = "0004_premium_flag"
down_revision = "0003_profile_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "is_premium",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "is_premium")
