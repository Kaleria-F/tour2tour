"""add stages table

Revision ID: 0003_stages
Revises: 0002_expenses
Create Date: 2026-03-15 00:30:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0003_stages"
down_revision = "0002_expenses"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "stages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("stage_type", sa.String(length=32), nullable=False),
        sa.Column("subtype", sa.String(length=64), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("start_location", sa.String(length=255), nullable=True),
        sa.Column("end_location", sa.String(length=255), nullable=True),
        sa.Column("address", sa.String(length=255), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
        sa.Column("cost_rub", sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column("reference_number", sa.String(length=128), nullable=True),
        sa.Column("website_url", sa.String(length=512), nullable=True),
        sa.Column("rating", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("document_key", sa.String(length=512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_stages_trip_id", "stages", ["trip_id"])
    op.create_index("ix_stages_position", "stages", ["position"])
    op.create_index("ix_stages_stage_type", "stages", ["stage_type"])
    op.create_index("ix_stages_subtype", "stages", ["subtype"])


def downgrade() -> None:
    op.drop_index("ix_stages_subtype", table_name="stages")
    op.drop_index("ix_stages_stage_type", table_name="stages")
    op.drop_index("ix_stages_position", table_name="stages")
    op.drop_index("ix_stages_trip_id", table_name="stages")
    op.drop_table("stages")
