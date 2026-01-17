"""create user_preferences table

Revision ID: d6787e7f18bd
Revises: 635655725c7b
Create Date: 2026-01-17 15:49:26.279062

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd6787e7f18bd'
down_revision: Union[str, Sequence[str], None] = '635655725c7b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_preferences",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("value", sa.String(), nullable=False),
    )
    op.create_index("ix_user_preferences_user_id", "user_preferences", ["user_id"])
    op.create_index("ix_user_preferences_key", "user_preferences", ["key"])
    op.create_index("ix_user_preferences_value", "user_preferences", ["value"])
    op.create_unique_constraint(
        "uq_user_preferences_user_key_value",
        "user_preferences",
        ["user_id", "key", "value"],
    )

def downgrade() -> None:
    op.drop_constraint("uq_user_preferences_user_key_value", "user_preferences", type_="unique")
    op.drop_index("ix_user_preferences_value", table_name="user_preferences")
    op.drop_index("ix_user_preferences_key", table_name="user_preferences")
    op.drop_index("ix_user_preferences_user_id", table_name="user_preferences")
    op.drop_table("user_preferences")