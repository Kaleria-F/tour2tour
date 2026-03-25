from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db.deps import get_db
from app.models.place import Place, PlaceCandidate, PlaceTag
from app.schemas.place import (
    ImportJobCreate,
    ImportJobOut,
    PlaceCandidateDecision,
    PlaceCandidateOut,
    PlaceCreate,
    PlaceListResponse,
    PlaceOut,
    PlaceUpdate,
)

router = APIRouter(prefix="/places", tags=["places"])


def _place_query():
    return select(Place).options(selectinload(Place.tags))


def _to_place_out(place: Place) -> PlaceOut:
    return PlaceOut(
        id=place.id,
        external_id=place.external_id,
        source=place.source,
        status=place.status,
        name=place.name,
        description=place.description,
        country=place.country,
        city=place.city,
        address=place.address,
        lat=place.lat,
        lon=place.lon,
        category=place.category,
        subcategory=place.subcategory,
        price_level=place.price_level,
        avg_visit_duration_min=place.avg_visit_duration_min,
        rating=place.rating,
        reviews_count=place.reviews_count,
        working_hours_json=place.working_hours_json,
        metadata_json=place.metadata_json,
        tags={tag.tag: tag.weight for tag in place.tags},
        created_at=place.created_at,
        updated_at=place.updated_at,
    )


def _replace_tags(db: Session, place: Place, tags: dict[str, int]) -> None:
    db.query(PlaceTag).filter(PlaceTag.place_id == place.id).delete()
    for tag, weight in tags.items():
        db.add(PlaceTag(id=str(uuid4()), place_id=place.id, tag=tag, weight=weight))


@router.get("", response_model=PlaceListResponse)
def list_places(
    city: str | None = None,
    category: str | None = None,
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    query = _place_query().order_by(Place.updated_at.desc())
    if city:
        query = query.where(Place.city == city)
    if category:
        query = query.where(Place.category == category)
    if status_filter:
        query = query.where(Place.status == status_filter)

    items = db.execute(query.offset(offset).limit(limit)).scalars().unique().all()
    total = len(db.execute(query).scalars().unique().all())
    return PlaceListResponse(items=[_to_place_out(item) for item in items], total=total)


@router.post("", response_model=PlaceOut, status_code=status.HTTP_201_CREATED)
def create_place(payload: PlaceCreate, db: Session = Depends(get_db)):
    place = Place(
        id=str(uuid4()),
        external_id=payload.external_id,
        source=payload.source,
        status=payload.status,
        name=payload.name,
        description=payload.description,
        country=payload.country,
        city=payload.city,
        address=payload.address,
        lat=payload.lat,
        lon=payload.lon,
        category=payload.category,
        subcategory=payload.subcategory,
        price_level=payload.price_level,
        avg_visit_duration_min=payload.avg_visit_duration_min,
        rating=payload.rating,
        reviews_count=payload.reviews_count or 0,
        working_hours_json=payload.working_hours_json,
        metadata_json=payload.metadata_json,
    )
    db.add(place)
    db.flush()
    _replace_tags(db, place, payload.tags)
    db.commit()
    place = db.execute(_place_query().where(Place.id == place.id)).scalar_one()
    return _to_place_out(place)


@router.get("/candidates/list", response_model=list[PlaceCandidateOut])
def list_candidates(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    query = select(PlaceCandidate).order_by(PlaceCandidate.updated_at.desc())
    if status_filter:
        query = query.where(PlaceCandidate.status == status_filter)
    items = db.execute(query.limit(limit)).scalars().all()
    return [
        PlaceCandidateOut(
            id=item.id,
            source=item.source,
            source_record_id=item.source_record_id,
            status=item.status,
            payload_json=item.payload_json,
            normalized_json=item.normalized_json,
            validation_score=item.validation_score,
            notes=item.notes,
            created_at=item.created_at,
            updated_at=item.updated_at,
        )
        for item in items
    ]


@router.post("/candidates/{candidate_id}/decision", response_model=PlaceCandidateOut)
def decide_candidate(candidate_id: str, payload: PlaceCandidateDecision, db: Session = Depends(get_db)):
    candidate = db.get(PlaceCandidate, candidate_id)
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found")
    candidate.status = payload.status
    candidate.notes = payload.notes
    db.add(candidate)
    db.commit()
    db.refresh(candidate)
    return PlaceCandidateOut(
        id=candidate.id,
        source=candidate.source,
        source_record_id=candidate.source_record_id,
        status=candidate.status,
        payload_json=candidate.payload_json,
        normalized_json=candidate.normalized_json,
        validation_score=candidate.validation_score,
        notes=candidate.notes,
        created_at=candidate.created_at,
        updated_at=candidate.updated_at,
    )


@router.post("/imports", response_model=ImportJobOut, status_code=status.HTTP_201_CREATED)
def create_import_job(payload: ImportJobCreate):
    return ImportJobOut(
        id=str(uuid4()),
        source=payload.source,
        kind=payload.kind,
        status="created",
        file_name=payload.file_name,
        stats_json={},
        created_by=payload.created_by,
    )


@router.get("/{place_id}", response_model=PlaceOut)
def get_place(place_id: str, db: Session = Depends(get_db)):
    place = db.execute(_place_query().where(Place.id == place_id)).scalar_one_or_none()
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")
    return _to_place_out(place)


@router.patch("/{place_id}", response_model=PlaceOut)
def update_place(place_id: str, payload: PlaceUpdate, db: Session = Depends(get_db)):
    place = db.execute(_place_query().where(Place.id == place_id)).scalar_one_or_none()
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")

    data = payload.model_dump(exclude_unset=True)
    tags = data.pop("tags", None)
    for key, value in data.items():
        setattr(place, key, value)
    if tags is not None:
        _replace_tags(db, place, tags)

    db.add(place)
    db.commit()
    place = db.execute(_place_query().where(Place.id == place_id)).scalar_one()
    return _to_place_out(place)
