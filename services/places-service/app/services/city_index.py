from __future__ import annotations

import csv
import json
from functools import lru_cache
from pathlib import Path
from typing import Any


def _repair_text(value: object | None) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""

    # Some local datasets are already decoded into mojibake like "РњРѕСЃРєРІР°".
    # Try to restore them, but keep the original value if the roundtrip fails.
    if any(marker in text for marker in ("Р", "С", "Ð", "Ñ")):
        try:
            repaired = text.encode("latin1").decode("utf-8")
            if repaired:
                text = repaired
        except UnicodeError:
            pass

    return text.replace("\xa0", " ").strip()


def _normalize(value: object | None) -> str:
    text = _repair_text(value)
    if not text:
        return ""
    return " ".join(text.casefold().replace("ё", "е").split())


def _pick(row: dict[str, Any], keys: list[str]) -> str | None:
    normalized_row = {_normalize(key): value for key, value in row.items()}
    for key in keys:
        value = normalized_row.get(_normalize(key))
        text = _repair_text(value)
        if text:
            return text
    return None


def _parse_float(value: object | None) -> float | None:
    text = _repair_text(value).replace(" ", "").replace(",", ".")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _parse_int(value: object | None) -> int | None:
    text = _repair_text(value).replace(" ", "").replace(",", ".")
    if not text:
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def _load_json(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        items = payload.get("items")
        payload = items if isinstance(items, list) else []
    if not isinstance(payload, list):
        return []
    return [item for item in payload if isinstance(item, dict)]


def _load_csv(path: Path) -> list[dict[str, Any]]:
    raw = path.read_bytes()
    decoded = None
    for encoding in ("utf-8-sig", "utf-8", "cp1251"):
        try:
            decoded = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    if decoded is None:
        return []

    sample = decoded[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(decoded.splitlines(), dialect=dialect)
    return [{str(key): value for key, value in row.items()} for row in reader]


def _shape_city_record(row: dict[str, Any]) -> dict[str, object] | None:
    region_payload = row.get("region") if isinstance(row.get("region"), dict) else {}
    timezone_payload = row.get("timezone") if isinstance(row.get("timezone"), dict) else {}
    coords_payload = row.get("coords") if isinstance(row.get("coords"), dict) else {}

    city = _pick(
        row,
        [
            "city",
            "name",
            "city_name",
            "settlement",
            "locality",
            "населенный пункт",
            "город",
        ],
    )
    if not city:
        return None

    region = (
        _pick(
            row,
            ["region", "region_name", "subject", "sub_region", "область", "регион"],
        )
        or _pick(region_payload, ["fullname", "name"])
    )
    district = _pick(row, ["federal_district", "district", "федеральный округ", "округ"]) or _pick(
        region_payload,
        ["district"],
    )
    country = _pick(row, ["country", "страна"]) or "Россия"
    lat = _parse_float(row.get("lat")) or _parse_float(row.get("latitude")) or _parse_float(
        row.get("geo_lat")
    ) or _parse_float(coords_payload.get("lat"))
    lon = _parse_float(row.get("lon")) or _parse_float(row.get("longitude")) or _parse_float(
        row.get("geo_lon")
    ) or _parse_float(coords_payload.get("lon"))
    population = _parse_int(row.get("population"))
    city_type = _pick(row, ["type", "kind", "settlement_type", "тип", "contentType"])
    timezone = _pick(timezone_payload, ["tzid", "abbreviation", "utcOffset"])

    display_parts = [city]
    if region:
        display_parts.append(region)
    display_name = ", ".join(display_parts)

    return {
        "city": city,
        "region": region,
        "district": district,
        "country": country,
        "display_name": display_name,
        "lat": lat,
        "lon": lon,
        "population": population,
        "type": city_type,
        "timezone": timezone,
    }


@lru_cache(maxsize=1)
def load_city_records(path_str: str) -> list[dict[str, object]]:
    path = Path(path_str)
    if not path.exists():
        return []

    raw_rows = _load_json(path) if path.suffix.lower() == ".json" else _load_csv(path)

    seen: set[tuple[str, str]] = set()
    records: list[dict[str, object]] = []
    for row in raw_rows:
        shaped = _shape_city_record(row)
        if not shaped:
            continue
        key = (_normalize(shaped["city"]), _normalize(shaped.get("region")))
        if key in seen:
            continue
        seen.add(key)
        records.append(shaped)

    records.sort(
        key=lambda item: (
            _normalize(item.get("city")),
            -int(item.get("population") or 0),
        )
    )
    return records

