"""add 2fa fields

Revision ID: 0002_2fa_fields
Revises: 0001_initial
Create Date: 2026-03-16
"""

from alembic import op
import sqlalchemy as sa


revision = "0002_2fa_fields"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("totp_enabled", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("users", sa.Column("passkey_enabled", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("users", sa.Column("totp_secret", sa.String(length=128), nullable=True))
    op.alter_column("users", "totp_enabled", server_default=None)
    op.alter_column("users", "passkey_enabled", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "totp_secret")
    op.drop_column("users", "passkey_enabled")
    op.drop_column("users", "totp_enabled")
