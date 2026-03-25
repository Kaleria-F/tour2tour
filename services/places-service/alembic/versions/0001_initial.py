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
        "places",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("external_id", sa.String(length=128), nullable=True),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="approved"),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("country", sa.String(length=64), nullable=True),
        sa.Column("city", sa.String(length=128), nullable=False),
        sa.Column("address", sa.String(length=255), nullable=True),
        sa.Column("lat", sa.Float(), nullable=True),
        sa.Column("lon", sa.Float(), nullable=True),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("subcategory", sa.String(length=64), nullable=True),
        sa.Column("price_level", sa.String(length=24), nullable=True),
        sa.Column("avg_visit_duration_min", sa.Integer(), nullable=True),
        sa.Column("rating", sa.Float(), nullable=True),
        sa.Column("reviews_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("working_hours_json", sa.JSON(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_places_status", "places", ["status"])
    op.create_index("ix_places_city", "places", ["city"])
    op.create_index("ix_places_category", "places", ["category"])
    op.create_index("ix_places_source_external_id", "places", ["source", "external_id"], unique=False)

    op.create_table(
        "place_tags",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("place_id", sa.String(length=36), sa.ForeignKey("places.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tag", sa.String(length=64), nullable=False),
        sa.Column("weight", sa.Integer(), nullable=False),
    )
    op.create_index("ix_place_tags_place_id", "place_tags", ["place_id"])
    op.create_index("ix_place_tags_tag", "place_tags", ["tag"])

    op.create_table(
        "place_candidates",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("source_record_id", sa.String(length=128), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="pending_review"),
        sa.Column("payload_json", sa.JSON(), nullable=False),
        sa.Column("normalized_json", sa.JSON(), nullable=True),
        sa.Column("validation_score", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_place_candidates_status", "place_candidates", ["status"])
    op.create_index("ix_place_candidates_source", "place_candidates", ["source"])

    op.create_table(
        "place_import_jobs",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("kind", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="created"),
        sa.Column("file_name", sa.String(length=255), nullable=True),
        sa.Column("stats_json", sa.JSON(), nullable=True),
        sa.Column("created_by", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_place_import_jobs_status", "place_import_jobs", ["status"])


def downgrade() -> None:
    op.drop_index("ix_place_import_jobs_status", table_name="place_import_jobs")
    op.drop_table("place_import_jobs")
    op.drop_index("ix_place_candidates_source", table_name="place_candidates")
    op.drop_index("ix_place_candidates_status", table_name="place_candidates")
    op.drop_table("place_candidates")
    op.drop_index("ix_place_tags_tag", table_name="place_tags")
    op.drop_index("ix_place_tags_place_id", table_name="place_tags")
    op.drop_table("place_tags")
    op.drop_index("ix_places_source_external_id", table_name="places")
    op.drop_index("ix_places_category", table_name="places")
    op.drop_index("ix_places_city", table_name="places")
    op.drop_index("ix_places_status", table_name="places")
    op.drop_table("places")
