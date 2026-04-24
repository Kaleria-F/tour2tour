from __future__ import annotations

from typing import Final


TAG_CATALOG: Final[list[dict[str, str]]] = [
    {
        "key": "history",
        "label": "История",
        "group": "interest",
        "color": "tag-blue",
        "description": "Исторические места, эпохи, события и наследие.",
    },
    {
        "key": "culture",
        "label": "Культура",
        "group": "interest",
        "color": "tag-violet",
        "description": "Культурные пространства, события и локальные традиции.",
    },
    {
        "key": "museums",
        "label": "Музеи",
        "group": "interest",
        "color": "tag-amber",
        "description": "Музеи, экспозиции и выставочные площадки.",
    },
    {
        "key": "architecture",
        "label": "Архитектура",
        "group": "interest",
        "color": "tag-cyan",
        "description": "Знаковые здания, стили и городская архитектура.",
    },
    {
        "key": "nature",
        "label": "Природа",
        "group": "interest",
        "color": "tag-green",
        "description": "Парки, сады, набережные и природные объекты.",
    },
    {
        "key": "food",
        "label": "Гастрономия",
        "group": "interest",
        "color": "tag-red",
        "description": "Еда, локальная кухня, кафе и рестораны.",
    },
    {
        "key": "active",
        "label": "Активный отдых",
        "group": "interest",
        "color": "tag-orange",
        "description": "Прогулки, спорт, активные развлечения и outdoor.",
    },
    {
        "key": "shopping",
        "label": "Шопинг",
        "group": "interest",
        "color": "tag-cyan",
        "description": "Магазины, рынки, торговые улицы и покупки.",
    },
    {
        "key": "photo",
        "label": "Фотолокации",
        "group": "interest",
        "color": "tag-amber",
        "description": "Места для красивых фото и визуально сильных видов.",
    },
    {
        "key": "nightlife",
        "label": "Ночная жизнь",
        "group": "interest",
        "color": "tag-purple",
        "description": "Бары, клубы, вечерние активности и nightlife.",
    },
    {
        "key": "hidden",
        "label": "Необычные места",
        "group": "interest",
        "color": "tag-green",
        "description": "Небанальные точки, hidden gems и нестандартные локации.",
    },
    {
        "key": "family",
        "label": "Семейный отдых",
        "group": "audience",
        "color": "tag-pink",
        "description": "Подходит для семейного посещения и поездок с детьми.",
    },
    {
        "key": "romantic",
        "label": "Романтика",
        "group": "trip_format",
        "color": "tag-rose",
        "description": "Подходит для романтического сценария поездки.",
    },
    {
        "key": "calm",
        "label": "Спокойный формат",
        "group": "trip_format",
        "color": "tag-green",
        "description": "Подходит для неспешного и расслабленного маршрута.",
    },
    {
        "key": "active_format",
        "label": "Активный формат",
        "group": "trip_format",
        "color": "tag-orange",
        "description": "Подходит для активного сценария поездки.",
    },
    {
        "key": "intense",
        "label": "Насыщенный формат",
        "group": "trip_format",
        "color": "tag-red",
        "description": "Подходит для плотного и насыщенного маршрута.",
    },
    {
        "key": "friends",
        "label": "С друзьями",
        "group": "audience",
        "color": "tag-violet",
        "description": "Хорошо работает для поездок с друзьями.",
    },
    {
        "key": "solo",
        "label": "Соло",
        "group": "audience",
        "color": "tag-blue",
        "description": "Подходит для одиночного путешествия.",
    },
    {
        "key": "couple",
        "label": "Для пары",
        "group": "audience",
        "color": "tag-rose",
        "description": "Подходит для поездки вдвоем.",
    },
    {
        "key": "landmark",
        "label": "Знаковое место",
        "group": "system",
        "color": "tag-cyan",
        "description": "Главная городская достопримечательность или must-see.",
    },
    {
        "key": "walk",
        "label": "Для прогулки",
        "group": "system",
        "color": "tag-green",
        "description": "Подходит для пеших прогулок и маршрутов.",
    },
    {
        "key": "city",
        "label": "Городской опыт",
        "group": "system",
        "color": "tag-default",
        "description": "Часть городского маршрута и знакомства с городом.",
    },
    {
        "key": "attraction",
        "label": "Точка притяжения",
        "group": "system",
        "color": "tag-amber",
        "description": "Яркая туристическая или локальная точка интереса.",
    },
    {
        "key": "cafe",
        "label": "Кафе-формат",
        "group": "system",
        "color": "tag-red",
        "description": "Точка короткой гастрономической остановки.",
    },
]

TAG_KEYS: Final[set[str]] = {item["key"] for item in TAG_CATALOG}
TAG_ALIASES: Final[dict[str, str]] = {
    "museum": "museums",
    "weekend": "calm",
}


def validate_place_tags(tags: dict[str, int] | None) -> dict[str, int]:
    if not tags:
        return {}

    normalized: dict[str, int] = {}
    unknown: list[str] = []
    invalid_weights: list[str] = []

    for raw_key, raw_weight in tags.items():
        key = str(raw_key).strip()
        if not key:
            continue
        key = TAG_ALIASES.get(key, key)
        if key not in TAG_KEYS:
            unknown.append(key)
            continue
        try:
            weight = int(raw_weight)
        except (TypeError, ValueError):
            invalid_weights.append(f"{key}={raw_weight}")
            continue
        if weight < 1 or weight > 5:
            invalid_weights.append(f"{key}={weight}")
            continue
        normalized[key] = weight

    if unknown:
        allowed = ", ".join(item["key"] for item in TAG_CATALOG)
        raise ValueError(f"Unknown tags: {', '.join(sorted(unknown))}. Allowed tags: {allowed}")
    if invalid_weights:
        raise ValueError(f"Tag weights must be integers from 1 to 5: {', '.join(invalid_weights)}")

    return normalized
