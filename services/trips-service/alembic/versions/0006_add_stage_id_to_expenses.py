"""add stage_id to expenses

Revision ID: 0006_add_stage_id_to_expenses
Revises: 0005_add_planned_days
Create Date: 2026-05-01 00:10:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_add_stage_id_to_expenses"
down_revision = "0005_add_planned_days"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("expenses", sa.Column("stage_id", sa.Integer(), nullable=True))
    op.create_index("ix_expenses_stage_id", "expenses", ["stage_id"])
    op.create_foreign_key(
        "fk_expenses_stage_id_stages",
        "expenses",
        "stages",
        ["stage_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint("fk_expenses_stage_id_stages", "expenses", type_="foreignkey")
    op.drop_index("ix_expenses_stage_id", table_name="expenses")
    op.drop_column("expenses", "stage_id")

