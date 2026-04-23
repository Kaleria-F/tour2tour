from __future__ import annotations

import math
import re
from collections import Counter
from typing import Any

import httpx
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    places_service_url: str = Field(default="http://places-service:8000", alias="PLACES_SERVICE_URL")
    interactions_service_url: str = Field(
        default="http://interactions-service:8000",
        alias="INTERACTIONS_SERVICE_URL",
    )

    model_config = SettingsConfigDict(extra="ignore")


settings = Settings()
app = FastAPI(title="Tour2Tour Recommendations Service")


class Place(BaseModel):
    id: str
    name: str
    description: str | None = None
    image_url: str | None = None
    category: str
    subcategory: str | None = None
    lat: float | None = None
    lon: float | None = None
    city: str
    address: str | None = None
    price_level: str | None = None
    avg_visit_duration_min: int | None = None
    rating: float | None = None
    tags: dict[str, int] = Field(default_factory=dict)


class SurveyProfile(BaseModel):
    interests: list[str] = Field(default_factory=list)
    trip_formats: list[str] = Field(default_factory=list)
    budget: str | None = None
    travel_mode: str | None = None
    pace: str | None = None
    interest_weights: dict[str, int] = Field(default_factory=dict)
    skipped: bool = False


class RecommendationsRequest(BaseModel):
    profile: SurveyProfile
    city: str | None = None
    near_route: bool = False
    route_latitude: float | None = None
    route_longitude: float | None = None
    user_id: str | None = None
    limit: int | None = Field(default=None, ge=1, le=50)


class RecommendationItem(BaseModel):
    id: str
    title: str
    description: str
    image_url: str
    category: str
    subcategory: str
    city: str
    address: str
    latitude: float
    longitude: float
    rating: float
    final_score: float
    interest_score: float
    budget_bonus: float
    distance_bonus: float
    trip_type_bonus: float
    popularity_bonus: float


class RecommendationCandidate(BaseModel):
    item: RecommendationItem
    raw_score: float


def _normalize_token(value: str | None) -> str:
    if not value:
        return ""
    normalized = value.casefold().replace("ё", "е")
    normalized = re.sub(r"[^a-zа-я0-9]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def _normalize_tags(tags: dict[str, int]) -> dict[str, int]:
    normalized: dict[str, int] = {}
    for tag, weight in tags.items():
        key = _normalize_token(tag)
        if not key:
            continue
        normalized[key] = int(weight)
    return normalized


def _city_matches(request_city: str | None, place_city: str | None) -> bool:
    requested = _normalize_token(request_city)
    current = _normalize_token(place_city)
    if not requested or not current:
        return False
    return requested == current or requested in current or current in requested


def _budget_bonus(user_budget: str | None, place_budget: str | None) -> float:
    if not user_budget or not place_budget:
        return 0.0
    order = {"economy": 1, "middle": 2, "comfort": 3, "premium": 4}
    user = order.get(user_budget, 2)
    place = order.get(place_budget, 2)
    diff = place - user
    if diff <= 0:
        return 8.0
    if diff == 1:
        return 2.0
    return -5.0


def _distance_km(
    first_lat: float | None,
    first_lon: float | None,
    second_lat: float | None,
    second_lon: float | None,
) -> float | None:
    if None in {first_lat, first_lon, second_lat, second_lon}:
        return None

    radius = 6371.0
    lat1 = math.radians(first_lat)
    lat2 = math.radians(second_lat)
    delta_lat = math.radians(second_lat - first_lat)
    delta_lon = math.radians(second_lon - first_lon)
    a = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    )
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _distance_bonus(
    near_route: bool,
    request_city: str | None,
    place_city: str | None,
    route_latitude: float | None,
    route_longitude: float | None,
    place_latitude: float | None,
    place_longitude: float | None,
) -> float:
    distance = _distance_km(route_latitude, route_longitude, place_latitude, place_longitude)
    if distance is not None:
        if distance <= 3:
            return 12.0 if near_route else 8.0
        if distance <= 10:
            return 8.0 if near_route else 5.0
        if distance <= 25:
            return 4.0 if near_route else 2.0

    if _city_matches(request_city, place_city):
        return 10.0 if near_route else 6.0
    if near_route:
        return 2.0
    return 0.0


def _trip_type_bonus(travel_mode: str | None, place_tags: dict[str, int]) -> float:
    travel_mode_key = _normalize_token(travel_mode)
    if not travel_mode_key:
        return 0.0
    return 6.0 if place_tags.get(travel_mode_key, 0) > 0 else 0.0


def _trip_format_bonus(trip_formats: list[str], place_tags: dict[str, int]) -> float:
    if not trip_formats:
        return 0.0
    bonus = 0.0
    for trip_format in trip_formats:
        trip_format_key = _normalize_token(trip_format)
        if place_tags.get(trip_format_key, 0) > 0:
            bonus += 2.0
    return min(bonus, 6.0)


def _pace_bonus(pace: str | None, duration_min: int | None, category: str, subcategory: str | None) -> float:
    pace_key = _normalize_token(pace)
    if not pace_key:
        return 0.0

    if duration_min is None:
        if pace_key == "slow" and category in {"place", "activity"}:
            return 1.0
        if pace_key == "intense" and (subcategory or "") in {"attraction", "event", "walk"}:
            return 1.0
        return 0.0

    if pace_key == "slow":
        if 60 <= duration_min <= 180:
            return 3.0
        if duration_min <= 240:
            return 1.0
        return -1.5

    if pace_key == "medium":
        if 45 <= duration_min <= 180:
            return 2.0
        if duration_min <= 240:
            return 1.0
        return -1.0

    if pace_key == "intense":
        if duration_min <= 90:
            return 3.0
        if duration_min <= 150:
            return 1.0
        return -2.0

    return 0.0


def _popularity_bonus(rating: float, reviews_count: int = 0) -> float:
    if rating >= 4.8:
        return 5.0
    if rating >= 4.5:
        return 3.0
    if rating >= 4.0 and reviews_count >= 20:
        return 1.5
    return 0.0


def _interest_score(interest_weights: dict[str, int], place_tags: dict[str, int]) -> float:
    score = 0.0
    for tag, user_weight in interest_weights.items():
        normalized_tag = _normalize_token(tag)
        if not normalized_tag:
            continue
        score += float(user_weight * place_tags.get(normalized_tag, 0))
    return score


def _default_interest_weights(city: str | None, near_route: bool) -> dict[str, int]:
    weights = {
        "culture": 3,
        "history": 3,
        "nature": 3,
        "food": 2,
        "architecture": 2,
        "museums": 2,
        "family": 1,
    }
    if city:
        weights.update({"landmark": 3, "walk": 2, "city": 2})
    if near_route:
        weights.update({"walk": 3, "attraction": 2, "cafe": 2})
    return weights


def _has_profile_signals(profile: SurveyProfile) -> bool:
    return bool(
        profile.interests
        or profile.trip_formats
        or profile.interest_weights
        or profile.budget
        or profile.travel_mode
        or profile.pace
    )


def _place_signal(place_id: str, user_summary: dict[str, Any] | None) -> dict[str, Any]:
    if not user_summary:
        return {}
    place_signals = user_summary.get("place_signals") or {}
    signal = place_signals.get(place_id)
    return signal if isinstance(signal, dict) else {}


def _behavior_bonus(place_id: str, user_summary: dict[str, Any] | None) -> float:
    signal = _place_signal(place_id, user_summary)
    if signal:
        raw_score = float(signal.get("score", 0.0) or 0.0)
    else:
        top_places = (user_summary or {}).get("top_places") or {}
        raw_score = float(top_places.get(place_id, 0.0) or 0.0)
    return max(min(raw_score, 15.0), -15.0)


def _data_quality_bonus(place: Place) -> float:
    bonus = 0.0
    if place.image_url:
        bonus += 0.8
    if place.address:
        bonus += 0.6
    if place.lat is not None and place.lon is not None:
        bonus += 0.8
    if place.description:
        bonus += 0.4
    return bonus


def _should_exclude_place(place_id: str, user_summary: dict[str, Any] | None) -> bool:
    signal = _place_signal(place_id, user_summary)
    if not signal:
        return False

    score = float(signal.get("score", 0.0) or 0.0)
    actions = signal.get("actions") or {}
    disliked = int(actions.get("disliked", 0) or 0)
    dismissed = int(actions.get("dismissed", 0) or 0)
    positive = int(actions.get("liked", 0) or 0) + int(actions.get("saved", 0) or 0) + int(
        actions.get("added_to_trip", 0) or 0
    )
    last_action = str(signal.get("last_action") or "")
    return score <= -3.0 or (disliked + dismissed > positive and last_action in {"disliked", "dismissed"})


def _fetch_places(city: str | None) -> list[Place]:
    with httpx.Client(timeout=10.0) as client:
        params: dict[str, Any] = {"status": "approved", "limit": 200}
        if city:
            params["city"] = city
        response = client.get(f"{settings.places_service_url.rstrip('/')}/places", params=params)
        response.raise_for_status()
        payload = response.json()
        items = payload.get("items") or []
        if city and not items:
            fallback = client.get(
                f"{settings.places_service_url.rstrip('/')}/places",
                params={"status": "approved", "limit": 200},
            )
            fallback.raise_for_status()
            items = (fallback.json() or {}).get("items") or []
    return [Place.model_validate(item) for item in items]


def _fetch_user_summary(user_id: str | None) -> dict[str, Any] | None:
    if not user_id:
        return None
    with httpx.Client(timeout=5.0) as client:
        response = client.get(
            f"{settings.interactions_service_url.rstrip('/')}/interactions/users/{user_id}/summary"
        )
        response.raise_for_status()
        return response.json()


def _default_limit(pace: str | None) -> int:
    pace_key = _normalize_token(pace)
    if pace_key == "slow":
        return 8
    if pace_key == "intense":
        return 16
    return 12


def _rerank_with_diversity(
    candidates: list[RecommendationCandidate],
    *,
    limit: int,
) -> list[RecommendationItem]:
    remaining = list(sorted(candidates, key=lambda candidate: candidate.raw_score, reverse=True))
    if not remaining:
        return []

    category_counts: Counter[str] = Counter()
    subcategory_counts: Counter[str] = Counter()
    ranked: list[RecommendationItem] = []

    while remaining and len(ranked) < limit:
        best_index = 0
        best_score = -10_000.0
        for idx, candidate in enumerate(remaining):
            category = _normalize_token(candidate.item.category)
            subcategory = _normalize_token(candidate.item.subcategory)
            penalty = category_counts[category] * 1.8 + subcategory_counts[f"{category}:{subcategory}"] * 0.9
            adjusted_score = candidate.raw_score - penalty
            if adjusted_score > best_score:
                best_index = idx
                best_score = adjusted_score

        selected = remaining.pop(best_index)
        ranked.append(selected.item)
        category_counts[_normalize_token(selected.item.category)] += 1
        subcategory_counts[
            f"{_normalize_token(selected.item.category)}:{_normalize_token(selected.item.subcategory)}"
        ] += 1

    return ranked


@app.post("/recommendations/personalized")
def personalized_recommendations(payload: RecommendationsRequest):
    items: list[RecommendationCandidate] = []
    weights = dict(payload.profile.interest_weights)

    if not weights:
        for tag in payload.profile.interests:
            normalized_tag = _normalize_token(tag)
            if normalized_tag:
                weights[normalized_tag] = 3

    if not weights:
        weights = _default_interest_weights(payload.city, payload.near_route)

    places = _fetch_places(payload.city)
    user_summary = _fetch_user_summary(payload.user_id)

    for place in places:
        if _should_exclude_place(place.id, user_summary):
            continue

        normalized_tags = _normalize_tags(place.tags)
        interest_score = _interest_score(weights, normalized_tags)
        budget_bonus = _budget_bonus(payload.profile.budget, place.price_level)
        if not _has_profile_signals(payload.profile) and place.price_level in {"economy", "middle", None}:
            budget_bonus += 1.0
        distance_bonus = _distance_bonus(
            payload.near_route,
            payload.city,
            place.city,
            payload.route_latitude,
            payload.route_longitude,
            place.lat,
            place.lon,
        )
        trip_type_bonus = (
            _trip_type_bonus(payload.profile.travel_mode, normalized_tags)
            + _trip_format_bonus(payload.profile.trip_formats, normalized_tags)
            + _behavior_bonus(place.id, user_summary)
            + _pace_bonus(payload.profile.pace, place.avg_visit_duration_min, place.category, place.subcategory)
            + _data_quality_bonus(place)
        )
        popularity_bonus = _popularity_bonus(place.rating or 0.0)
        final_score = (
            interest_score + budget_bonus + distance_bonus + trip_type_bonus + popularity_bonus
        )
        items.append(
            RecommendationCandidate(
                raw_score=round(final_score, 2),
                item=RecommendationItem(
                    id=place.id,
                    title=place.name,
                    description=place.description or "",
                    image_url=place.image_url or "",
                    category=place.category,
                    subcategory=place.subcategory or "",
                    city=place.city,
                    address=place.address or "",
                    latitude=place.lat or 0.0,
                    longitude=place.lon or 0.0,
                    rating=place.rating or 0.0,
                    final_score=round(final_score, 2),
                    interest_score=round(interest_score, 2),
                    budget_bonus=round(budget_bonus, 2),
                    distance_bonus=round(distance_bonus, 2),
                    trip_type_bonus=round(trip_type_bonus, 2),
                    popularity_bonus=round(popularity_bonus, 2),
                ),
            )
        )

    limit = payload.limit or _default_limit(payload.profile.pace)
    ranked = _rerank_with_diversity(items, limit=limit)
    return {"items": ranked}


SUGGESTION_TEMPLATES: dict[tuple[str, str], list[dict[str, Any]]] = {
    ("transport", "airplane"): [
        {
            "title": "Заселение рядом с аэропортом",
            "stage_type": "stay",
            "subtype": "hotel",
            "reason": "После перелета удобно сразу добавить проживание рядом с точкой прибытия.",
            "estimated_cost_rub": "5500.00",
        },
        {
            "title": "Ужин после прилета",
            "stage_type": "food",
            "subtype": "restaurant",
            "reason": "После перелета полезно добавить короткую остановку на еду без длинного переезда.",
            "estimated_cost_rub": "1800.00",
        },
    ],
    ("transport", "train"): [
        {
            "title": "Завтрак у вокзала",
            "stage_type": "food",
            "subtype": "cafe",
            "reason": "Удобный первый прием пищи после прибытия поездом.",
            "estimated_cost_rub": "900.00",
        },
        {
            "title": "Проживание ближе к центру",
            "stage_type": "stay",
            "subtype": "hotel",
            "reason": "Помогает сократить трансфер после приезда и быстрее начать маршрут.",
            "estimated_cost_rub": "4800.00",
        },
    ],
    ("stay", "hotel"): [
        {
            "title": "Музей рядом с отелем",
            "stage_type": "place",
            "subtype": "museum",
            "reason": "Близкая культурная точка для первого свободного окна в маршруте.",
            "estimated_cost_rub": "700.00",
        },
        {
            "title": "Ужин в шаговой доступности",
            "stage_type": "food",
            "subtype": "restaurant",
            "reason": "Легко добавить к вечернему маршруту без лишних переездов.",
            "estimated_cost_rub": "2000.00",
        },
    ],
}

DEFAULT_SUGGESTIONS: list[dict[str, Any]] = [
    {
        "title": "Добавить место по пути",
        "stage_type": "place",
        "subtype": "attraction",
        "reason": "Базовая рекомендация для расширения маршрута рядом с текущей точкой.",
    },
    {
        "title": "Добавить прием пищи",
        "stage_type": "food",
        "subtype": "cafe",
        "reason": "Помогает сбалансировать маршрут и не оставлять длинные интервалы без пауз.",
        "estimated_cost_rub": "1200.00",
    },
]
@app.get("/recommendations/suggestions")
def stage_suggestions(
    stage_type: str = Query(..., min_length=1),
    subtype: str = Query(..., min_length=1),
    location: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
):
    key = (_normalize_token(stage_type), _normalize_token(subtype))
    base_items = SUGGESTION_TEMPLATES.get(key, DEFAULT_SUGGESTIONS)
    suffix = location.strip() if location else None

    items: list[dict[str, Any]] = []
    for item in base_items:
        prepared = dict(item)
        if suffix and not prepared.get("address"):
            prepared["address"] = suffix
        if latitude is not None and longitude is not None:
            prepared["latitude"] = latitude
            prepared["longitude"] = longitude
        items.append(prepared)
    return {"items": items}


@app.get("/health")
def health():
    return {"status": "ok"}

