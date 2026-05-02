from __future__ import annotations

import csv
import io
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import distinct, func, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_admin
from app.core.config import settings
from app.db.deps import get_db
from app.models.place import Place, PlaceCandidate, PlaceImportJob, PlaceStory, PlaceTag
from app.schemas.place import (
    CitySuggestionOut,
    ImportJobCreate,
    ImportJobOut,
    PlaceCandidateDecision,
    PlaceCandidateOut,
    PlaceCreate,
    PlaceListResponse,
    PlaceOut,
    PlaceStoryCreate,
    PlaceStoryOut,
    PlaceStoryPlaceOut,
    PlaceStoryUpdate,
    PlaceUpdate,
    TagCatalogItemOut,
)
from app.services.city_index import load_city_records
from app.tag_catalog import TAG_CATALOG, validate_place_tags

router = APIRouter(prefix="/places", tags=["places"])


def _normalize_city_query(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.casefold().replace("ё", "е").split())


def _search_city_records(
    query: str,
    limit: int,
    db: Session,
) -> list[CitySuggestionOut]:
    normalized_query = _normalize_city_query(query)
    if len(normalized_query) < 2:
        return []

    ranked_items: list[tuple[int, int, CitySuggestionOut]] = []
    seen: set[str] = set()

    for record in load_city_records(settings.city_data_path):
        city = str(record.get("city") or "").strip()
        region = str(record.get("region") or "").strip()
        display_name = str(record.get("display_name") or city).strip()
        searchable = [
            _normalize_city_query(city),
            _normalize_city_query(region),
            _normalize_city_query(display_name),
        ]
        if not any(normalized_query in candidate for candidate in searchable if candidate):
            continue
        match_priority = 3
        normalized_city = _normalize_city_query(city)
        normalized_display = _normalize_city_query(display_name)
        if normalized_city.startswith(normalized_query):
            match_priority = 0
        elif normalized_display.startswith(normalized_query):
            match_priority = 1
        elif normalized_query == normalized_city:
            match_priority = 0
        key = f"{_normalize_city_query(city)}|{_normalize_city_query(region)}"
        if key in seen:
            continue
        seen.add(key)
        ranked_items.append(
            (
                match_priority,
                -int(record.get("population") or 0),
                CitySuggestionOut(
                city=city,
                region=region or None,
                district=str(record.get("district") or "").strip() or None,
                country=str(record.get("country") or "Россия"),
                display_name=display_name,
                lat=record.get("lat"),
                lon=record.get("lon"),
                population=record.get("population"),
                type=str(record.get("type") or "").strip() or None,
                source="city_dataset",
                ),
            )
        )

    ranked_items.sort(key=lambda item: (item[0], item[1], _normalize_city_query(item[2].city)))
    items = [item[2] for item in ranked_items[:limit]]
    if len(items) >= limit:
        return items

    known_cities = db.execute(
        select(distinct(Place.city)).where(Place.city.is_not(None)).order_by(Place.city.asc()).limit(500)
    ).scalars().all()
    for city in known_cities:
        normalized_city = _normalize_city_query(city)
        if normalized_query not in normalized_city:
            continue
        key = f"{normalized_city}|"
        if key in seen:
            continue
        seen.add(key)
        items.append(
            CitySuggestionOut(
                city=city,
                display_name=city,
                source="places_db",
            )
        )
        if len(items) >= limit:
            break

    return items


def _place_query():
    return select(Place).options(selectinload(Place.tags))


def _story_query():
    return select(PlaceStory).options(selectinload(PlaceStory.place))


def _to_place_out(place: Place) -> PlaceOut:
    return PlaceOut(
        id=place.id,
        external_id=place.external_id,
        source=place.source,
        status=place.status,
        name=place.name,
        description=place.description,
        image_url=place.image_url,
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


def _to_story_out(story: PlaceStory) -> PlaceStoryOut:
    place_out = None
    if story.place is not None:
        place_out = PlaceStoryPlaceOut(
            id=story.place.id,
            name=story.place.name,
            city=story.place.city,
            image_url=story.place.image_url,
            address=story.place.address,
            category=story.place.category,
            subcategory=story.place.subcategory,
            rating=story.place.rating,
            description=story.place.description,
        )
    return PlaceStoryOut(
        id=story.id,
        title=story.title,
        cover_image_url=story.cover_image_url,
        image_url=story.image_url,
        body_text=story.body_text,
        place_id=story.place_id,
        sort_order=story.sort_order,
        is_active=story.is_active,
        place=place_out,
        created_at=story.created_at,
        updated_at=story.updated_at,
    )


def _replace_tags(db: Session, place: Place, tags: dict[str, int]) -> None:
    tags = validate_place_tags(tags)
    if "tags" in place.__dict__:
        place.tags.clear()
    db.query(PlaceTag).filter(PlaceTag.place_id == place.id).delete(synchronize_session=False)
    db.flush()
    for tag, weight in tags.items():
        db.add(PlaceTag(id=str(uuid4()), place_id=place.id, tag=tag, weight=weight))


def _pick(row: dict[str, str], keys: list[str]) -> str | None:
    for key in keys:
        value = row.get(key)
        if value is not None:
            value = value.strip()
            if value:
                return value
    return None


def _parse_tags(raw: str | None) -> dict[str, int]:
    if not raw:
        return {}
    raw = raw.strip()
    if not raw:
        return {}
    try:
        import json

        parsed = json.loads(raw)
    except Exception:
        parsed = None
    if isinstance(parsed, dict):
        return validate_place_tags({str(key): int(value) for key, value in parsed.items() if str(key).strip()})

    result: dict[str, int] = {}
    chunks = raw.split(",")
    if len(chunks) == 1 and ";" in raw:
        chunks = raw.split(";")
    for chunk in chunks:
        part = chunk.strip()
        if not part:
            continue
        if ":" in part:
            tag, weight = part.split(":", 1)
        elif "=" in part:
            tag, weight = part.split("=", 1)
        else:
            tag, weight = part, "3"
        tag = tag.strip()
        if not tag:
            continue
        result[tag] = int(weight.strip() or "3")
    return validate_place_tags(result)


def _detect_csv_delimiter(sample: str) -> str:
    first_line = sample.splitlines()[0] if sample.splitlines() else sample
    counts = {
        ";": first_line.count(";"),
        ",": first_line.count(","),
        "\t": first_line.count("\t"),
    }
    if counts[";"] >= counts[","] and counts[";"] >= counts["\t"] and counts[";"] > 0:
        return ";"
    if counts["\t"] > counts[","] and counts["\t"] > 0:
        return "\t"
    if counts[","] > 0:
        return ","
    try:
        return csv.Sniffer().sniff(sample, delimiters=",;\t").delimiter
    except csv.Error:
        return ","


def _normalize_candidate_row(row: dict[str, str], default_source: str) -> dict:
    source = _pick(row, ["source"]) or default_source
    return {
        "external_id": _pick(row, ["external_id", "source_id", "id", "externalId"]),
        "source": source,
        "status": "approved",
        "name": _pick(row, ["name", "title"]),
        "description": _pick(row, ["description"]),
        "image_url": _pick(row, ["image_url", "photo_url", "image", "photo"]),
        "country": _pick(row, ["country"]),
        "city": _pick(row, ["city"]),
        "address": _pick(row, ["address"]),
        "lat": _pick(row, ["lat", "latitude"]),
        "lon": _pick(row, ["lon", "longitude"]),
        "category": _pick(row, ["category"]) or "place",
        "subcategory": _pick(row, ["subcategory", "subtype"]),
        "price_level": _pick(row, ["price_level", "budget"]),
        "avg_visit_duration_min": _pick(row, ["avg_visit_duration_min", "visit_minutes", "duration_minutes"]),
        "rating": _pick(row, ["rating"]),
        "reviews_count": _pick(row, ["reviews_count"]),
        "tags": _parse_tags(_pick(row, ["tags_json", "tags"])),
    }


def _build_place_from_payload(payload: dict) -> Place:
    def _as_float(value):
        if value in (None, ""):
            return None
        return float(str(value).replace(",", "."))

    def _as_int(value):
        if value in (None, ""):
            return None
        return int(float(str(value).replace(",", ".")))

    return Place(
        id=str(uuid4()),
        external_id=payload.get("external_id"),
        source=payload.get("source") or "import",
        status=payload.get("status") or "approved",
        name=(payload.get("name") or "").strip(),
        description=payload.get("description"),
        image_url=payload.get("image_url"),
        country=payload.get("country"),
        city=(payload.get("city") or "").strip(),
        address=payload.get("address"),
        lat=_as_float(payload.get("lat")),
        lon=_as_float(payload.get("lon")),
        category=(payload.get("category") or "place").strip(),
        subcategory=payload.get("subcategory"),
        price_level=payload.get("price_level"),
        avg_visit_duration_min=_as_int(payload.get("avg_visit_duration_min")),
        rating=_as_float(payload.get("rating")),
        reviews_count=_as_int(payload.get("reviews_count")) or 0,
        working_hours_json=payload.get("working_hours_json"),
        metadata_json=payload.get("metadata_json"),
    )


def _create_place_from_candidate(db: Session, candidate: PlaceCandidate) -> Place | None:
    normalized = candidate.normalized_json or candidate.payload_json
    if not isinstance(normalized, dict):
        return None
    if not normalized.get("name") or not normalized.get("city"):
        return None

    existing_query = select(Place).where(
        Place.name == str(normalized.get("name")).strip(),
        Place.city == str(normalized.get("city")).strip(),
        Place.address == normalized.get("address"),
    )
    existing = db.execute(existing_query).scalar_one_or_none()
    if existing:
        return existing

    place = _build_place_from_payload(normalized)
    db.add(place)
    db.flush()
    _replace_tags(db, place, dict(normalized.get("tags") or {}))
    return place


@router.get("", response_model=PlaceListResponse)
def list_places(
    city: str | None = None,
    category: str | None = None,
    q: str | None = Query(default=None, min_length=1, max_length=128),
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    query = _place_query().order_by(Place.updated_at.desc())
    count_query = select(func.count()).select_from(Place)
    if city:
        query = query.where(Place.city == city)
        count_query = count_query.where(Place.city == city)
    if category:
        query = query.where(Place.category == category)
        count_query = count_query.where(Place.category == category)
    if status_filter:
        query = query.where(Place.status == status_filter)
        count_query = count_query.where(Place.status == status_filter)
    if q:
        pattern = f"%{q.strip()}%"
        query = query.where((Place.name.ilike(pattern)) | (Place.city.ilike(pattern)))
        count_query = count_query.where((Place.name.ilike(pattern)) | (Place.city.ilike(pattern)))

    items = db.execute(query.offset(offset).limit(limit)).scalars().unique().all()
    total = db.execute(count_query).scalar_one()
    return PlaceListResponse(items=[_to_place_out(item) for item in items], total=total)


@router.post("", response_model=PlaceOut, status_code=status.HTTP_201_CREATED)
def create_place(
    payload: PlaceCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    place = Place(
        id=str(uuid4()),
        external_id=payload.external_id,
        source=payload.source,
        status=payload.status,
        name=payload.name,
        description=payload.description,
        image_url=payload.image_url,
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


@router.get("/cities/suggest", response_model=list[CitySuggestionOut])
def suggest_cities(
    q: str = Query(..., min_length=2, max_length=128),
    limit: int = Query(default=8, ge=1, le=20),
    db: Session = Depends(get_db),
):
    return _search_city_records(q, limit, db)


@router.get("/tags/catalog", response_model=list[TagCatalogItemOut])
def list_tag_catalog():
    return [TagCatalogItemOut(**item) for item in TAG_CATALOG]


@router.get("/stories", response_model=list[PlaceStoryOut])
def list_place_stories(
    active_only: bool = Query(default=True),
    db: Session = Depends(get_db),
):
    query = _story_query().order_by(PlaceStory.sort_order.asc(), PlaceStory.updated_at.desc())
    if active_only:
        query = query.where(PlaceStory.is_active.is_(True))
    stories = db.execute(query).scalars().unique().all()
    return [_to_story_out(story) for story in stories]


@router.get("/stories/admin", response_model=list[PlaceStoryOut])
def list_place_stories_admin(
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    stories = db.execute(
        _story_query().order_by(PlaceStory.sort_order.asc(), PlaceStory.updated_at.desc())
    ).scalars().unique().all()
    return [_to_story_out(story) for story in stories]


@router.post("/stories", response_model=PlaceStoryOut, status_code=status.HTTP_201_CREATED)
def create_place_story(
    payload: PlaceStoryCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    linked_place = None
    if payload.place_id:
        linked_place = db.get(Place, payload.place_id)
        if linked_place is None:
            raise HTTPException(status_code=404, detail="Linked place not found")
    story = PlaceStory(
        id=str(uuid4()),
        title=payload.title,
        cover_image_url=payload.cover_image_url,
        image_url=payload.image_url,
        body_text=payload.body_text,
        place_id=linked_place.id if linked_place else None,
        sort_order=payload.sort_order,
        is_active=payload.is_active,
    )
    db.add(story)
    db.commit()
    story = db.execute(_story_query().where(PlaceStory.id == story.id)).scalar_one()
    return _to_story_out(story)


@router.patch("/stories/{story_id}", response_model=PlaceStoryOut)
def update_place_story(
    story_id: str,
    payload: PlaceStoryUpdate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    story = db.execute(_story_query().where(PlaceStory.id == story_id)).scalar_one_or_none()
    if story is None:
        raise HTTPException(status_code=404, detail="Story not found")
    data = payload.model_dump(exclude_unset=True)
    if "place_id" in data:
        place_id = data.get("place_id")
        if place_id:
            linked_place = db.get(Place, place_id)
            if linked_place is None:
                raise HTTPException(status_code=404, detail="Linked place not found")
            story.place_id = linked_place.id
        else:
            story.place_id = None
        data.pop("place_id", None)
    for key, value in data.items():
        setattr(story, key, value)
    db.add(story)
    db.commit()
    db.expire_all()
    story = db.execute(_story_query().where(PlaceStory.id == story_id)).scalar_one()
    return _to_story_out(story)


@router.delete("/stories/{story_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_place_story(
    story_id: str,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    story = db.get(PlaceStory, story_id)
    if story is None:
        raise HTTPException(status_code=404, detail="Story not found")
    db.delete(story)
    db.commit()


@router.get("/candidates/list", response_model=list[PlaceCandidateOut])
def list_candidates(
    status_filter: str | None = Query(default="pending_review", alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
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


@router.delete("/candidates/{candidate_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_candidate(
    candidate_id: str,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    candidate = db.get(PlaceCandidate, candidate_id)
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found")
    db.delete(candidate)
    db.commit()


@router.post("/candidates/{candidate_id}/decision", response_model=PlaceCandidateOut)
def decide_candidate(
    candidate_id: str,
    payload: PlaceCandidateDecision,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    candidate = db.get(PlaceCandidate, candidate_id)
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found")
    should_create_place = payload.status == "approved" and candidate.status != "approved"
    candidate.status = payload.status
    candidate.notes = payload.notes
    db.add(candidate)
    if should_create_place:
        try:
            created_place = _create_place_from_candidate(db, candidate)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        if created_place is None:
            raise HTTPException(
                status_code=400,
                detail="Candidate is missing required fields to create a place",
            )
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
def create_import_job(
    payload: ImportJobCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    job = PlaceImportJob(
        id=str(uuid4()),
        source=payload.source,
        kind=payload.kind,
        status="created",
        file_name=payload.file_name,
        stats_json={},
        created_by=payload.created_by,
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return ImportJobOut(
        id=job.id,
        source=job.source,
        kind=job.kind,
        status=job.status,
        file_name=job.file_name,
        stats_json=job.stats_json or {},
        created_by=job.created_by,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )


@router.get("/imports/list", response_model=list[ImportJobOut])
def list_import_jobs(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    jobs = db.execute(
        select(PlaceImportJob).order_by(PlaceImportJob.updated_at.desc()).limit(limit)
    ).scalars().all()
    return [
        ImportJobOut(
            id=job.id,
            source=job.source,
            kind=job.kind,
            status=job.status,
            file_name=job.file_name,
            stats_json=job.stats_json or {},
            created_by=job.created_by,
            created_at=job.created_at,
            updated_at=job.updated_at,
        )
        for job in jobs
    ]


@router.post("/upload-image")
async def upload_place_image(
    file: UploadFile = File(...),
    _: dict = Depends(require_admin),
):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    extension = Path(file.filename or "image").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        extension = ".jpg"

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    target_name = f"{uuid4()}{extension}"
    target_path = Path(settings.place_images_dir) / target_name
    target_path.write_bytes(content)
    return {"url": f"{settings.place_images_base_url.rstrip('/')}/{target_name}"}


@router.post("/imports/upload", response_model=ImportJobOut, status_code=status.HTTP_201_CREATED)
async def upload_import_csv(
    source: str = Form(...),
    kind: str = Form(default="places"),
    created_by: str | None = Form(default=None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    raw_bytes = await file.read()
    decoded = None
    for encoding in ("utf-8-sig", "utf-8", "cp1251"):
        try:
            decoded = raw_bytes.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    if decoded is None:
        raise HTTPException(status_code=400, detail="Unable to decode CSV file")

    job = PlaceImportJob(
        id=str(uuid4()),
        source=source,
        kind=kind,
        status="processing",
        file_name=file.filename,
        stats_json={},
        created_by=created_by,
    )
    db.add(job)
    db.flush()

    created = 0
    failed = 0
    sample = decoded[:4096]
    delimiter = _detect_csv_delimiter(sample)
    reader = csv.DictReader(io.StringIO(decoded), delimiter=delimiter)

    for index, row in enumerate(reader, start=2):
        payload_row = {str(key): str(value or "") for key, value in row.items()}
        try:
            normalized = _normalize_candidate_row(payload_row, source)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=f"Invalid tags format in CSV row {index}: {exc}") from exc
        if not normalized.get("name") or not normalized.get("city"):
            failed += 1
            continue
        candidate = PlaceCandidate(
            id=str(uuid4()),
            source=normalized.get("source") or source,
            source_record_id=normalized.get("external_id"),
            status="pending_review",
            payload_json=payload_row,
            normalized_json=normalized,
            validation_score=0.9,
            notes=None,
        )
        db.add(candidate)
        created += 1

    job.status = "completed"
    job.stats_json = {
        "rows_total": created + failed,
        "candidates_created": created,
        "rows_failed": failed,
    }
    db.add(job)
    db.commit()
    db.refresh(job)
    return ImportJobOut(
        id=job.id,
        source=job.source,
        kind=job.kind,
        status=job.status,
        file_name=job.file_name,
        stats_json=job.stats_json or {},
        created_by=job.created_by,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )


@router.get("/{place_id}", response_model=PlaceOut)
def get_place(place_id: str, db: Session = Depends(get_db)):
    place = db.execute(_place_query().where(Place.id == place_id)).scalar_one_or_none()
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")
    return _to_place_out(place)


@router.patch("/{place_id}", response_model=PlaceOut)
def update_place(
    place_id: str,
    payload: PlaceUpdate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
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
    db.expire_all()
    place = db.execute(_place_query().where(Place.id == place_id)).scalar_one()
    return _to_place_out(place)


@router.delete("/{place_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_place(
    place_id: str,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
):
    place = db.get(Place, place_id)
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")
    db.delete(place)
    db.commit()


