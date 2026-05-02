"""add profile fields

Revision ID: 0003_profile_fields
Revises: 0002_2fa_fields
Create Date: 2026-05-02
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_profile_fields"
down_revision = "0002_2fa_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("display_name", sa.String(length=128), nullable=True))
    op.add_column("users", sa.Column("avatar_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "avatar_url")
    op.drop_column("users", "display_name")
