from __future__ import annotations

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
    user_id: str | None = None


class RecommendationItem(BaseModel):
    id: str
    title: str
    description: str
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


def _distance_bonus(near_route: bool, request_city: str | None, place_city: str) -> float:
    if near_route:
        return 10.0
    if request_city and request_city.strip().lower() == place_city.strip().lower():
        return 5.0
    return 0.0


def _trip_type_bonus(travel_mode: str | None, place_tags: dict[str, int]) -> float:
    if not travel_mode:
        return 0.0
    return 6.0 if place_tags.get(travel_mode, 0) > 0 else 0.0


def _trip_format_bonus(trip_formats: list[str], place_tags: dict[str, int]) -> float:
    if not trip_formats:
        return 0.0
    bonus = 0.0
    for trip_format in trip_formats:
        if place_tags.get(trip_format, 0) > 0:
            bonus += 2.0
    return min(bonus, 6.0)


def _popularity_bonus(rating: float) -> float:
    if rating >= 4.8:
        return 5.0
    if rating >= 4.5:
        return 3.0
    return 0.0


def _interest_score(interest_weights: dict[str, int], place_tags: dict[str, int]) -> float:
    score = 0.0
    for tag, user_weight in interest_weights.items():
        score += float(user_weight * place_tags.get(tag, 0))
    return score


def _behavior_bonus(place_id: str, user_summary: dict[str, Any] | None) -> float:
    if not user_summary:
        return 0.0
    top_places = user_summary.get("top_places") or {}
    raw_score = float(top_places.get(place_id, 0.0) or 0.0)
    return max(min(raw_score, 12.0), -12.0)


def _fetch_places(city: str | None) -> list[Place]:
    params: dict[str, Any] = {"status": "approved", "limit": 200}
    if city:
        params["city"] = city
    with httpx.Client(timeout=10.0) as client:
        response = client.get(f"{settings.places_service_url.rstrip('/')}/places", params=params)
        response.raise_for_status()
        payload = response.json()
    items = payload.get("items") or []
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


@app.post("/recommendations/personalized")
def personalized_recommendations(payload: RecommendationsRequest):
    items: list[RecommendationItem] = []
    weights = dict(payload.profile.interest_weights)

    if not weights:
        for tag in payload.profile.interests:
            if tag:
                weights[tag] = 3

    places = _fetch_places(payload.city)
    user_summary = _fetch_user_summary(payload.user_id)

    for place in places:
        interest_score = _interest_score(weights, place.tags)
        budget_bonus = _budget_bonus(payload.profile.budget, place.price_level)
        distance_bonus = _distance_bonus(payload.near_route, payload.city, place.city)
        trip_type_bonus = (
            _trip_type_bonus(payload.profile.travel_mode, place.tags)
            + _trip_format_bonus(payload.profile.trip_formats, place.tags)
            + _behavior_bonus(place.id, user_summary)
        )
        popularity_bonus = _popularity_bonus(place.rating or 0.0)
        final_score = (
            interest_score + budget_bonus + distance_bonus + trip_type_bonus + popularity_bonus
        )
        items.append(
            RecommendationItem(
                id=place.id,
                title=place.name,
                description=place.description or "",
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
            )
        )

    ranked = sorted(items, key=lambda item: item.final_score, reverse=True)
    return {"items": ranked}


SUGGESTION_TEMPLATES: dict[tuple[str, str], list[dict[str, Any]]] = {
    ("transport", "airplane"): [
        {
            "title": "Заселение рядом с аэропортом",
            "stage_type": "stay",
            "subtype": "hotel",
            "reason": "После перелета удобно добавить проживание",
            "estimated_cost_rub": "5500.00",
        },
        {
            "title": "Ужин после прилета",
            "stage_type": "food",
            "subtype": "restaurant",
            "reason": "После перелета часто нужен быстрый прием пищи",
            "estimated_cost_rub": "1800.00",
        },
    ],
    ("transport", "train"): [
        {
            "title": "Завтрак у вокзала",
            "stage_type": "food",
            "subtype": "cafe",
            "reason": "Удобно после прибытия на вокзал",
            "estimated_cost_rub": "900.00",
        },
        {
            "title": "Проживание рядом с центром",
            "stage_type": "stay",
            "subtype": "hotel",
            "reason": "Сокращает трансфер после поездки",
            "estimated_cost_rub": "4800.00",
        },
    ],
    ("stay", "hotel"): [
        {
            "title": "Музей рядом с отелем",
            "stage_type": "place",
            "subtype": "museum",
            "reason": "Близкая культурная точка для первого дня",
            "estimated_cost_rub": "700.00",
        },
        {
            "title": "Ужин в шаговой доступности",
            "stage_type": "food",
            "subtype": "restaurant",
            "reason": "Легко добавить к вечернему маршруту",
            "estimated_cost_rub": "2000.00",
        },
    ],
}

DEFAULT_SUGGESTIONS: list[dict[str, Any]] = [
    {
        "title": "Добавить место по пути",
        "stage_type": "place",
        "subtype": "attraction",
        "reason": "Базовая рекомендация для расширения маршрута",
    },
    {
        "title": "Добавить прием пищи",
        "stage_type": "food",
        "subtype": "cafe",
        "reason": "Помогает сбалансировать план на день",
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
    key = (stage_type.strip().lower(), subtype.strip().lower())
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
