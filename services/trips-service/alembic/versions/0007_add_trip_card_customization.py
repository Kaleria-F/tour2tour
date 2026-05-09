"""add trip card customization fields

Revision ID: 0007_add_trip_card_customization
Revises: 0006_add_stage_id_to_expenses
Create Date: 2026-05-09 18:20:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0007_add_trip_card_customization"
down_revision = "0006_add_stage_id_to_expenses"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("trips", sa.Column("card_color", sa.String(length=16), nullable=True))
    op.add_column("trips", sa.Column("card_background", sa.String(length=32), nullable=True))
    op.add_column("trips", sa.Column("card_icon", sa.String(length=32), nullable=True))


def downgrade() -> None:
    op.drop_column("trips", "card_icon")
    op.drop_column("trips", "card_background")
    op.drop_column("trips", "card_color")

