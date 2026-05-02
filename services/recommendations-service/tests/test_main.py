from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app.main as recommendations_main
from app.main import (
    RecommendationCandidate,
    RecommendationItem,
    SurveyProfile,
    _budget_bonus,
    _default_limit,
    _rerank_with_diversity,
    app,
)


client = TestClient(app)


def _place(
    *,
    place_id: str,
    name: str,
    category: str = "place",
    subcategory: str = "museum",
    city: str = "Moscow",
    price_level: str | None = "middle",
    rating: float = 4.7,
    tags: dict[str, int] | None = None,
    lat: float = 55.7558,
    lon: float = 37.6173,
    duration: int | None = 90,
    image_url: str = "https://example.com/image.jpg",
    address: str = "Tverskaya, 1",
    description: str = "Description",
) -> dict[str, object]:
    return {
        "id": place_id,
        "name": name,
        "description": description,
        "image_url": image_url,
        "category": category,
        "subcategory": subcategory,
        "lat": lat,
        "lon": lon,
        "city": city,
        "address": address,
        "price_level": price_level,
        "avg_visit_duration_min": duration,
        "rating": rating,
        "tags": tags or {},
    }


def _candidate(item_id: str, category: str, subcategory: str, raw_score: float) -> RecommendationCandidate:
    return RecommendationCandidate(
        raw_score=raw_score,
        item=RecommendationItem(
            id=item_id,
            title=item_id,
            description="",
            image_url="",
            category=category,
            subcategory=subcategory,
            city="Moscow",
            address="",
            latitude=0.0,
            longitude=0.0,
            rating=4.5,
            final_score=raw_score,
            interest_score=0.0,
            budget_bonus=0.0,
            distance_bonus=0.0,
            trip_type_bonus=0.0,
            popularity_bonus=0.0,
        ),
    )


def test_survey_profile_rejects_unknown_interest_tag() -> None:
    with pytest.raises(ValidationError):
        SurveyProfile(interests=["history", "unknown-tag"])


def test_survey_profile_rejects_invalid_interest_weight() -> None:
    with pytest.raises(ValidationError):
        SurveyProfile(interest_weights={"history": 7})


@pytest.mark.parametrize(
    ("user_budget", "place_budget", "expected"),
    [
        ("economy", "economy", 8.0),
        ("middle", "comfort", 2.0),
        ("economy", "premium", -5.0),
        (None, "premium", 0.0),
    ],
)
def test_budget_bonus(user_budget: str | None, place_budget: str | None, expected: float) -> None:
    assert _budget_bonus(user_budget, place_budget) == expected


@pytest.mark.parametrize(
    ("pace", "expected"),
    [
        ("slow", 8),
        ("medium", 12),
        ("intense", 16),
        (None, 12),
    ],
)
def test_default_limit_depends_on_pace(pace: str | None, expected: int) -> None:
    assert _default_limit(pace) == expected


def test_rerank_with_diversity_spreads_categories() -> None:
    candidates = [
        _candidate("museum-1", "place", "museum", 30.0),
        _candidate("museum-2", "place", "museum", 29.0),
        _candidate("museum-3", "place", "museum", 28.0),
        _candidate("food-1", "food", "restaurant", 27.5),
        _candidate("walk-1", "activity", "walk", 27.0),
    ]

    ranked = _rerank_with_diversity(candidates, limit=4)

    assert [item.id for item in ranked] == ["museum-1", "food-1", "walk-1", "museum-2"]


def test_personalized_recommendations_excludes_negative_places_and_uses_user_signals(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        recommendations_main,
        "_fetch_places",
        lambda city: [
            _place(
                place_id="liked-place",
                name="Favorite place",
                tags={"history": 4, "friends": 1},
                rating=4.8,
                price_level="middle",
            ),
            _place(
                place_id="hidden-place",
                name="Hidden place",
                tags={"history": 5},
                rating=4.9,
                price_level="economy",
            ),
        ],
    )
    monkeypatch.setattr(
        recommendations_main,
        "_fetch_user_summary",
        lambda user_id: {
            "place_signals": {
                "liked-place": {
                    "score": 6.0,
                    "actions": {"liked": 1, "saved": 1},
                    "last_action": "liked",
                },
                "hidden-place": {
                    "score": -4.0,
                    "actions": {"disliked": 1, "dismissed": 1},
                    "last_action": "disliked",
                },
            }
        },
    )

    response = client.post(
        "/recommendations/personalized",
        json={
            "city": "Moscow",
            "user_id": "user-1",
            "profile": {
                "interests": ["history"],
                "travel_mode": "friends",
                "budget": "middle",
            },
        },
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert [item["id"] for item in items] == ["liked-place"]
    assert items[0]["trip_type_bonus"] >= 6.0
    assert items[0]["popularity_bonus"] == 5.0


def test_personalized_recommendations_uses_default_weights_for_empty_profile(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        recommendations_main,
        "_fetch_places",
        lambda city: [
            _place(
                place_id="city-walk",
                name="City walk",
                category="activity",
                subcategory="walk",
                tags={"landmark": 2, "walk": 3, "city": 2},
                city="Kazan",
                rating=4.4,
            ),
            _place(
                place_id="generic-food",
                name="Generic cafe",
                category="food",
                subcategory="cafe",
                tags={"food": 1},
                city="Samara",
                rating=4.4,
            ),
        ],
    )
    monkeypatch.setattr(recommendations_main, "_fetch_user_summary", lambda user_id: None)

    response = client.post(
        "/recommendations/personalized",
        json={
            "city": "Kazan",
            "near_route": True,
            "profile": {
                "interests": [],
                "trip_formats": [],
                "interest_weights": {},
                "skipped": True,
            },
        },
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert [item["id"] for item in items] == ["city-walk", "generic-food"]
    assert items[0]["interest_score"] > items[1]["interest_score"]
    assert items[0]["distance_bonus"] >= 10.0


def test_stage_suggestions_fill_location_and_coordinates() -> None:
    response = client.get(
        "/recommendations/suggestions",
        params={
            "stage_type": "transport",
            "subtype": "airplane",
            "location": "Sheremetyevo",
            "latitude": 55.9726,
            "longitude": 37.4146,
        },
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 2
    assert all(item["address"] == "Sheremetyevo" for item in items)
    assert all(item["latitude"] == 55.9726 for item in items)
    assert all(item["longitude"] == 37.4146 for item in items)


def test_stage_suggestions_use_default_template_for_unknown_stage() -> None:
    response = client.get(
        "/recommendations/suggestions",
        params={"stage_type": "unknown", "subtype": "unknown"},
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 2
    assert {item["stage_type"] for item in items} == {"place", "food"}
