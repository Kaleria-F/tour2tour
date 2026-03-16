from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import FastAPI, Query

app = FastAPI(title="Tour2Tour Recommendations Service")


class Place(BaseModel):
    id: str
    title: str
    description: str
    category: str
    subcategory: str
    latitude: float
    longitude: float
    city: str
    address: str
    price_level: str
    visit_minutes: int
    rating: float
    tags: dict[str, int]
    trip_type_tags: list[str] = Field(default_factory=list)


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


PLACES: list[Place] = [
    Place(
        id="hermitage",
        title="Эрмитаж",
        description="Крупнейший музей искусства и истории",
        category="place",
        subcategory="museum",
        latitude=59.9398,
        longitude=30.3146,
        city="Санкт-Петербург",
        address="Дворцовая площадь, 2",
        price_level="middle",
        visit_minutes=180,
        rating=4.9,
        tags={
            "history": 5,
            "culture": 5,
            "museums": 5,
            "architecture": 4,
            "family": 3,
        },
        trip_type_tags=["family", "solo", "friends"],
    ),
    Place(
        id="gorky-park",
        title="Парк Горького",
        description="Городской парк для прогулок и активностей",
        category="place",
        subcategory="park",
        latitude=55.7298,
        longitude=37.6034,
        city="Москва",
        address="ул. Крымский Вал, 9",
        price_level="economy",
        visit_minutes=120,
        rating=4.7,
        tags={
            "nature": 4,
            "active": 4,
            "family": 4,
            "photo": 3,
            "local": 3,
        },
        trip_type_tags=["family", "friends", "solo"],
    ),
    Place(
        id="rooftop-view",
        title="Смотровая площадка Ривьера",
        description="Панорамный вид на город и море",
        category="place",
        subcategory="attraction",
        latitude=43.6031,
        longitude=39.7340,
        city="Сочи",
        address="Центральный район",
        price_level="comfort",
        visit_minutes=90,
        rating=4.6,
        tags={
            "photo": 5,
            "nature": 3,
            "romantic": 4,
            "culture": 2,
        },
        trip_type_tags=["couple", "solo", "friends"],
    ),
    Place(
        id="local-food-market",
        title="Центральный гастромаркет",
        description="Локальная кухня и фермерские продукты",
        category="food",
        subcategory="market",
        latitude=55.7541,
        longitude=37.6207,
        city="Москва",
        address="ул. Петровка, 10",
        price_level="middle",
        visit_minutes=80,
        rating=4.5,
        tags={
            "gastronomy": 5,
            "local": 4,
            "shopping": 3,
            "culture": 2,
        },
        trip_type_tags=["friends", "couple", "solo"],
    ),
    Place(
        id="mountain-park",
        title="Горный парк",
        description="Природа, тропы, смотровые точки",
        category="activity",
        subcategory="nature",
        latitude=43.6805,
        longitude=40.2073,
        city="Сочи",
        address="Красная Поляна",
        price_level="comfort",
        visit_minutes=220,
        rating=4.8,
        tags={
            "nature": 5,
            "active": 4,
            "photo": 5,
            "family": 4,
        },
        trip_type_tags=["family", "friends", "solo"],
    ),
]


def _budget_bonus(user_budget: str | None, place_budget: str) -> float:
    if not user_budget:
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


def _trip_type_bonus(travel_mode: str | None, trip_type_tags: list[str]) -> float:
    if not travel_mode:
        return 0.0
    return 6.0 if travel_mode in trip_type_tags else 0.0


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
        place_weight = place_tags.get(tag, 0)
        score += float(user_weight * place_weight)
    return score


@app.post("/recommendations/personalized")
def personalized_recommendations(payload: RecommendationsRequest):
    items: list[RecommendationItem] = []
    weights = dict(payload.profile.interest_weights)

    if not weights:
        for tag in payload.profile.interests:
            if tag:
                weights[tag] = 3

    for place in PLACES:
        interest_score = _interest_score(weights, place.tags)
        budget_bonus = _budget_bonus(payload.profile.budget, place.price_level)
        distance_bonus = _distance_bonus(payload.near_route, payload.city, place.city)
        trip_type_bonus = (
            _trip_type_bonus(payload.profile.travel_mode, place.trip_type_tags)
            + _trip_format_bonus(payload.profile.trip_formats, place.tags)
        )
        popularity_bonus = _popularity_bonus(place.rating)
        final_score = (
            interest_score + budget_bonus + distance_bonus + trip_type_bonus + popularity_bonus
        )
        items.append(
            RecommendationItem(
                id=place.id,
                title=place.title,
                description=place.description,
                category=place.category,
                subcategory=place.subcategory,
                city=place.city,
                address=place.address,
                latitude=place.latitude,
                longitude=place.longitude,
                rating=place.rating,
                final_score=round(final_score, 2),
                interest_score=round(interest_score, 2),
                budget_bonus=round(budget_bonus, 2),
                distance_bonus=round(distance_bonus, 2),
                trip_type_bonus=round(trip_type_bonus, 2),
                popularity_bonus=round(popularity_bonus, 2),
            )
        )

    ranked = sorted(items, key=lambda i: i.final_score, reverse=True)
    return {"items": ranked}


SUGGESTION_TEMPLATES: dict[tuple[str, str], list[dict]] = {
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
        {
            "title": "Популярное место рядом",
            "stage_type": "place",
            "subtype": "attraction",
            "reason": "Можно добавить точку рядом с местом прибытия",
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

DEFAULT_SUGGESTIONS: list[dict] = [
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

    items: list[dict] = []
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
