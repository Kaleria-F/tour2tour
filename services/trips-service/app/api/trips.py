import json
import re
import urllib.error
import urllib.parse
import urllib.request
import wave
from decimal import Decimal, InvalidOperation
from datetime import timedelta
from io import BytesIO

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.db.deps import get_db
from app.models.expense import Expense
from app.models.stage import Stage
from app.models.trip import Trip
from app.schemas.expense import ExpenseCreate, ExpenseOut, ExpenseUpdate
from app.schemas.stage import (
    StageCreate,
    StageAssistantDraftOut,
    StageAssistantDraftRequest,
    StageAssistantTranscriptionOut,
    StageOut,
    StageReorderRequest,
    StageSuggestionOut,
    StageUpdate,
)
from app.schemas.trip import TripCreate, TripOut, TripUpdate

router = APIRouter(prefix="/trips", tags=["trips"])

STAGE_SUBTYPES: dict[str, set[str]] = {
    "transport": {
        "road",
        "airplane",
        "train",
        "car",
        "bus",
        "public_transport",
        "walk",
        "taxi",
        "bicycle",
    },
    "place": {"attraction", "excursion", "museum", "park", "event", "nature"},
    "stay": {"hotel", "hostel", "apartment", "overnight", "rest"},
    "food": {"restaurant", "cafe", "fastfood", "breakfast", "lunch", "dinner", "to_go"},
    "shopping": {"mall", "market", "souvenirs", "shopping"},
    "activity": {"sport", "entertainment", "walk", "beach"},
    "document": {"tickets", "visa", "insurance", "booking"},
}

STAGE_TYPE_TO_EXPENSE_CATEGORY: dict[str, str] = {
    "transport": "transport",
    "place": "entertainment",
    "stay": "housing",
    "food": "food",
    "shopping": "shopping",
    "activity": "entertainment",
}

_DEFAULT_SUBTYPE_BY_TYPE: dict[str, str] = {
    "transport": "road",
    "place": "attraction",
    "stay": "hotel",
    "food": "restaurant",
    "shopping": "shopping",
    "activity": "entertainment",
    "document": "booking",
}

_TIME_RE = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")

ORS_MODES = {
    "driving-car",
    "foot-walking",
    "cycling-regular",
}

CARD_COLORS = {
    "#D7E37A",
    "#B6A1FF",
    "#E3BA7A",
    "#A3E37A",
    "#E37AA2",
    "#7AE3BA",
    "#7AB4E3",
}

CARD_BACKGROUNDS = {
    "orbit",
    "waves",
    "mountains",
    "sunset",
    "aurora",
    "city_text",
    "brand_text",
}
CARD_ICONS = {"luggage", "flight", "terrain", "beach", "car", "forest", "camera"}


class OrsPoint(BaseModel):
    lon: float = Field(..., ge=-180, le=180)
    lat: float = Field(..., ge=-90, le=90)


class OrsRouteRequest(BaseModel):
    mode: str = Field(default="driving-car")
    points: list[OrsPoint] = Field(..., min_length=2, max_length=25)


class OrsRouteResponse(BaseModel):
    mode: str
    distance_m: float
    duration_s: float
    geometry: dict


@router.get("/", response_model=list[TripOut])
def list_trips(
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    stmt = select(Trip).where(Trip.user_id == user_id).order_by(Trip.id.desc())
    return db.execute(stmt).scalars().all()


def _get_user_trip_or_404(db: Session, trip_id: int, user_id: int) -> Trip:
    trip = db.execute(
        select(Trip).where(
            Trip.id == trip_id,
            Trip.user_id == user_id,
        )
    ).scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


def _get_user_stage_or_404(db: Session, trip_id: int, stage_id: int) -> Stage:
    stage = db.execute(
        select(Stage).where(
            Stage.id == stage_id,
            Stage.trip_id == trip_id,
        )
    ).scalars().first()
    if not stage:
        raise HTTPException(status_code=404, detail="Stage not found")
    return stage


def _get_trip_expense_or_404(db: Session, trip_id: int, expense_id: int) -> Expense:
    expense = db.execute(
        select(Expense).where(
            Expense.id == expense_id,
            Expense.trip_id == trip_id,
        )
    ).scalars().first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return expense


def _validate_stage_type_and_subtype(stage_type: str, subtype: str) -> tuple[str, str]:
    normalized_type = stage_type.strip().lower()
    normalized_subtype = subtype.strip().lower()
    if normalized_type not in STAGE_SUBTYPES:
        raise HTTPException(status_code=400, detail="Invalid stage type")
    if normalized_subtype not in STAGE_SUBTYPES[normalized_type]:
        raise HTTPException(status_code=400, detail="Invalid stage subtype for selected type")
    return normalized_type, normalized_subtype


def _require_yandex_credentials() -> tuple[str, str]:
    api_key = (settings.yandex_api_key or "").strip()
    folder_id = (settings.yandex_folder_id or "").strip()
    if not api_key or not folder_id:
        raise HTTPException(
            status_code=503,
            detail="Yandex AI integration is not configured",
        )
    return api_key, folder_id


def _trim_optional_text(value, *, max_length: int = 255) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    return text[:max_length]


def _parse_optional_decimal(value) -> Decimal | None:
    if value in (None, ""):
        return None
    try:
        parsed = Decimal(str(value).replace(",", "."))
    except (InvalidOperation, ValueError):
        return None
    if parsed < 0:
        return None
    return parsed.quantize(Decimal("0.01"))


def _validate_time_text(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or not _TIME_RE.fullmatch(text):
        return None
    return text


def _normalize_card_color(value: str | None) -> str:
    raw = (value or "").strip().upper()
    if raw and raw in CARD_COLORS:
        return raw
    return "#D7E37A"


def _normalize_card_background(value: str | None) -> str:
    raw = (value or "").strip().lower()
    if raw in CARD_BACKGROUNDS:
        return raw
    return "brand_text"


def _normalize_card_icon(value: str | None) -> str:
    raw = (value or "").strip().lower()
    if raw in CARD_ICONS:
        return raw
    return "luggage"


def _default_stage_title(stage_type: str, subtype: str) -> str:
    if stage_type == "transport" and subtype == "road":
        return "Дорога"
    labels = {
        "road": "Дорога",
        "airplane": "Самолет",
        "train": "Поезд",
        "car": "Автомобиль",
        "bus": "Автобус",
        "public_transport": "Общественный транспорт",
        "walk": "Пешком",
        "taxi": "Такси",
        "bicycle": "Велосипед",
        "attraction": "Достопримечательность",
        "excursion": "Экскурсия",
        "museum": "Музей",
        "park": "Парк",
        "event": "Мероприятие",
        "nature": "Природный объект",
        "hotel": "Отель",
        "hostel": "Хостел",
        "apartment": "Апартаменты",
        "overnight": "Ночевка",
        "rest": "Отдых",
        "restaurant": "Ресторан",
        "cafe": "Кафе",
        "fastfood": "Фастфуд",
        "breakfast": "Завтрак",
        "lunch": "Обед",
        "dinner": "Ужин",
        "to_go": "Взять с собой",
        "mall": "Торговый центр",
        "market": "Рынок",
        "souvenirs": "Сувениры",
        "shopping": "Покупки",
        "sport": "Спорт",
        "entertainment": "Развлечения",
        "beach": "Пляж",
        "tickets": "Билеты",
        "visa": "Виза",
        "insurance": "Страховка",
        "booking": "Бронь",
    }
    return labels.get(subtype, subtype.replace("_", " ").strip().title() or "Этап")


def _extract_json_object(raw_text: str) -> dict:
    text = raw_text.strip()
    if not text:
        raise ValueError("Empty model response")
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object in model response")
    parsed = json.loads(text[start : end + 1])
    if not isinstance(parsed, dict):
        raise ValueError("Model response is not an object")
    return parsed


def _normalize_stage_assistant_draft(
    raw: dict,
    *,
    requested_stage_type: str | None,
    source_text: str,
) -> StageAssistantDraftOut:
    stage_type = requested_stage_type or _normalize_detected_stage_type(
        raw_stage_type=raw.get("stage_type"),
        source_text=source_text,
    )
    subtype = str(raw.get("subtype") or "").strip().lower()
    if subtype not in STAGE_SUBTYPES.get(stage_type, set()):
        subtype = _DEFAULT_SUBTYPE_BY_TYPE.get(stage_type, next(iter(STAGE_SUBTYPES[stage_type])))

    title = _trim_optional_text(raw.get("title"), max_length=255) or _default_stage_title(
        stage_type,
        subtype,
    )
    start_time_text = _validate_time_text(raw.get("start_time_text"))
    end_time_text = _validate_time_text(raw.get("end_time_text"))
    duration_minutes = raw.get("duration_minutes")
    try:
        duration_minutes = int(duration_minutes) if duration_minutes is not None else None
    except (TypeError, ValueError):
        duration_minutes = None
    if duration_minutes is not None and duration_minutes < 0:
        duration_minutes = None

    time_mode = "range" if start_time_text and end_time_text else "duration"
    return StageAssistantDraftOut(
        stage_type=stage_type,
        subtype=subtype,
        title=title,
        start_location=_trim_optional_text(raw.get("start_location")),
        end_location=_trim_optional_text(raw.get("end_location")),
        address=_trim_optional_text(raw.get("address")),
        start_time_text=start_time_text,
        end_time_text=end_time_text,
        duration_minutes=duration_minutes,
        cost_rub=_parse_optional_decimal(raw.get("cost_rub")),
        notes=_trim_optional_text(raw.get("notes"), max_length=2000),
        time_mode=time_mode,
        source_text=source_text.strip(),
    )


def _normalize_detected_stage_type(*, raw_stage_type, source_text: str) -> str:
    candidate = str(raw_stage_type or "").strip().lower()
    if candidate in STAGE_SUBTYPES:
        return candidate

    text = source_text.lower()
    quick_groups = [
        ("food", ("хочу поесть", "поесть", "покушать", "перекус", "кафе", "ресторан", "ужин", "обед", "завтрак", "кофе", "бар", "фастфуд")),
        ("stay", ("хочу отдохнуть", "отдохнуть", "заселиться", "заселение", "выезд", "ночевка", "переночевать", "отель", "гостиниц", "апартамент", "хостел", "жилье", "проживание")),
        ("transport", ("доехать", "добраться", "поездка", "дорога", "перелет", "рейс", "самолет", "поезд", "электричк", "автобус", "такси", "машин", "метро", "трансфер", "паром")),
        ("document", ("билет", "брониров", "бронь", "страховк", "виза", "документ", "полис", "подтверждение", "ваучер")),
        ("shopping", ("шопинг", "покупк", "купить", "магазин", "рынок", "сувенир", "торгов", "тц", "маркет")),
        ("place", ("достопримеч", "музей", "галере", "парк", "экскурси", "храм", "собор", "театр", "выставк", "смотров", "хочу посмотреть", "хочу сходить", "посетить")),
        ("activity", ("погулять", "прогулк", "развлеч", "катани", "активност", "спорт", "плавать", "пляж", "концерт", "квест", "парк аттракционов")),
    ]
    for stage_type, keywords in quick_groups:
        if any(keyword in text for keyword in keywords):
            return stage_type

    keyword_groups = [
        (
            "food",
            (
                "хочу поесть",
                "поесть",
                "покушать",
                "перекус",
                "кафе",
                "ресторан",
                "ужин",
                "обед",
                "завтрак",
                "кофе",
                "бар",
                "фастфуд",
            ),
        ),
        (
            "stay",
            (
                "хочу отдохнуть",
                "отдохнуть",
                "заселиться",
                "заселение",
                "выезд",
                "ночевка",
                "переночевать",
                "отель",
                "гостиниц",
                "апартамент",
                "хостел",
                "жилье",
                "проживание",
            ),
        ),
        (
            "transport",
            (
                "доехать",
                "добраться",
                "поездка",
                "дорога",
                "перелет",
                "рейс",
                "самолет",
                "поезд",
                "электричк",
                "автобус",
                "такси",
                "машин",
                "метро",
                "трансфер",
                "паром",
            ),
        ),
        (
            "document",
            (
                "билет",
                "брониров",
                "бронь",
                "страховк",
                "виза",
                "документ",
                "полис",
                "подтверждение",
                "ваучер",
            ),
        ),
        (
            "shopping",
            (
                "шопинг",
                "покупк",
                "купить",
                "магазин",
                "рынок",
                "сувенир",
                "торгов",
                "тц",
                "маркет",
            ),
        ),
        (
            "place",
            (
                "достопримеч",
                "музей",
                "галере",
                "парк",
                "экскурси",
                "храм",
                "собор",
                "театр",
                "выставк",
                "смотров",
                "хочу посмотреть",
                "хочу сходить",
                "посетить",
            ),
        ),
        (
            "activity",
            (
                "погулять",
                "прогулк",
                "развлеч",
                "катани",
                "активност",
                "спорт",
                "плавать",
                "пляж",
                "концерт",
                "квест",
                "парк аттракционов",
            ),
        ),
    ]
    for stage_type, keywords in keyword_groups:
        if any(keyword in text for keyword in keywords):
            return stage_type
    return "place"


def _speechkit_transcribe_lpcm(audio_bytes: bytes) -> str:
    api_key, _ = _require_yandex_credentials()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty")
    if len(audio_bytes) > 1_000_000:
        raise HTTPException(status_code=400, detail="Audio payload is too large")

    endpoint = (
        "https://stt.api.cloud.yandex.net/speech/v1/stt:recognize"
        "?lang=ru-RU&topic=general&format=lpcm&sampleRateHertz=16000"
    )
    request = urllib.request.Request(
        endpoint,
        data=audio_bytes,
        method="POST",
        headers={
            "Authorization": f"Api-Key {api_key}",
            "Content-Type": "application/octet-stream",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise HTTPException(status_code=502, detail=f"SpeechKit request failed: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail="SpeechKit request failed") from exc

    result = str(payload.get("result") or "").strip()
    if not result:
        raise HTTPException(status_code=422, detail="Speech was not recognized")
    return result


def _extract_pcm_from_upload(file: UploadFile, content: bytes) -> bytes:
    filename = (file.filename or "").lower()
    content_type = (file.content_type or "").lower()
    if filename.endswith(".wav") or "wav" in content_type:
        try:
            with wave.open(BytesIO(content), "rb") as wav_file:
                if wav_file.getnchannels() != 1:
                    raise HTTPException(status_code=400, detail="Only mono audio is supported")
                if wav_file.getsampwidth() != 2:
                    raise HTTPException(status_code=400, detail="Only 16-bit PCM audio is supported")
                if wav_file.getframerate() != 16000:
                    raise HTTPException(status_code=400, detail="Use 16 kHz audio recording")
                return wav_file.readframes(wav_file.getnframes())
        except wave.Error as exc:
            raise HTTPException(status_code=400, detail="Invalid WAV file") from exc
    return content


def _generate_stage_assistant_draft(
    *,
    stage_type: str | None,
    source_text: str,
    route_day=None,
) -> StageAssistantDraftOut:
    api_key, folder_id = _require_yandex_credentials()
    normalized_type = stage_type.strip().lower() if stage_type else None
    if normalized_type is not None and normalized_type not in STAGE_SUBTYPES:
        raise HTTPException(status_code=400, detail="Invalid stage type")
    requested_stage_type = normalized_type
    normalized_type = normalized_type or "place"

    system_prompt = (
        "Ты заполняешь поля этапа маршрута для travel-приложения. "
        "Верни только JSON-объект без markdown и пояснений. "
        "Тип этапа уже выбран пользователем, менять его нельзя. "
        "Используй только допустимые подтипы для этого типа. "
        "Поля ответа: subtype, title, start_location, end_location, address, "
        "start_time_text, end_time_text, duration_minutes, cost_rub, notes. "
        "Время возвращай только в формате HH:MM или null. "
        "Если пользователь не указал время окончания, но указал длительность, "
        "заполни duration_minutes. Если данных нет, ставь null. "
        "Название делай коротким и понятным. Не выдумывай факты."
    )
    user_prompt = (
        f"Тип этапа: {normalized_type}\n"
        f"Дата маршрута: {route_day.isoformat() if route_day else 'не указана'}\n"
        f"Допустимые подтипы: {', '.join(sorted(STAGE_SUBTYPES[normalized_type]))}\n"
        f"Текст пользователя:\n{source_text.strip()}"
    )
    system_prompt = (
        "You fill route stage fields for a travel app. "
        "Return only one JSON object without markdown or explanations. "
        "Response fields: stage_type, subtype, title, start_location, end_location, address, "
        "start_time_text, end_time_text, duration_minutes, cost_rub, notes. "
        "Return time only as HH:MM or null. "
        "If the stage type is explicitly provided by the user, keep that stage type and use only allowed subtypes for it. "
        "If the stage type is not provided, infer it from the user's intent. "
        "Use food if the user wants to eat, drink coffee, have breakfast, lunch, dinner, visit a cafe, bar, restaurant, or snack. "
        "Use stay if the user wants to rest, sleep, check in, stay in a hotel, hostel, apartment, or spend the night. "
        "Use transport if the user describes moving somewhere, a road, transfer, flight, train, bus, taxi, metro, ferry, or driving. "
        "Use place if the user wants to visit a museum, gallery, park, attraction, excursion, exhibition, sightseeing spot, or landmark. "
        "Use activity if the user wants to walk, relax on a beach, do sport, entertainment, a concert, or another activity. "
        "Use shopping if the user wants to shop, buy something, visit a market, mall, or souvenir store. "
        "Use document if the user mentions a ticket, booking, reservation, voucher, insurance, visa, or another travel document. "
        "If the user mentions a specific name of a place, hotel, apartment, restaurant, museum, park, event, route, or venue, "
        "you must put that exact specific name into the title field. "
        "Do not replace a mentioned proper name with a generic subtype label like Hotel, Restaurant, Museum, Flight, or Road. "
        "Use a generic subtype-based title only when the source text contains no specific proper name at all. "
        "If the user gave a duration but no explicit end time, fill duration_minutes. "
        "If data is missing, use null. Keep the title short and clear. Do not invent facts."
    )
    if requested_stage_type is None:
        stage_options = "\n".join(
            f"- {name}: {', '.join(sorted(subtypes))}"
            for name, subtypes in STAGE_SUBTYPES.items()
        )
        user_prompt = (
            "Selected stage type: not provided\n"
            f"Route day: {route_day.isoformat() if route_day else 'not specified'}\n"
            "Available stage types and subtypes:\n"
            f"{stage_options}\n"
            f"User text:\n{source_text.strip()}"
        )
    else:
        user_prompt = (
            f"Selected stage type: {normalized_type}\n"
            f"Route day: {route_day.isoformat() if route_day else 'not specified'}\n"
            f"Allowed subtypes for this stage type: {', '.join(sorted(STAGE_SUBTYPES[normalized_type]))}\n"
            f"User text:\n{source_text.strip()}"
        )
    body = {
        "modelUri": f"gpt://{folder_id}/yandexgpt-lite",
        "completionOptions": {
            "stream": False,
            "temperature": 0,
            "maxTokens": "800",
        },
        "messages": [
            {"role": "system", "text": system_prompt},
            {"role": "user", "text": user_prompt},
        ],
    }
    request = urllib.request.Request(
        "https://llm.api.cloud.yandex.net/foundationModels/v1/completion",
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Api-Key {api_key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise HTTPException(status_code=502, detail=f"YandexGPT request failed: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail="YandexGPT request failed") from exc

    try:
        raw_text = payload["result"]["alternatives"][0]["message"]["text"]
        raw_object = _extract_json_object(raw_text)
    except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail="Invalid YandexGPT response") from exc

    return _normalize_stage_assistant_draft(
        raw_object,
        requested_stage_type=requested_stage_type,
        source_text=source_text,
    )


def _create_expense_from_stage_if_needed(stage: Stage, db: Session) -> None:
    _sync_stage_expense(stage=stage, db=db)


def _sync_stage_expense(
    stage: Stage,
    db: Session,
    *,
    legacy_title: str | None = None,
    legacy_category: str | None = None,
    legacy_amount=None,
) -> None:
    existing = db.execute(
        select(Expense).where(
            Expense.trip_id == stage.trip_id,
            Expense.stage_id == stage.id,
        )
    ).scalars().first()

    category = STAGE_TYPE_TO_EXPENSE_CATEGORY.get(stage.stage_type, "other")
    has_cost = stage.cost_rub is not None and stage.cost_rub > 0

    if not has_cost:
        if existing is not None:
            db.delete(existing)
        return

    if existing is None:
        # Backward-compatibility: bind legacy auto-expense rows created before stage_id existed.
        legacy = db.execute(
            select(Expense).where(
                Expense.trip_id == stage.trip_id,
                Expense.stage_id.is_(None),
                Expense.description == stage.title.strip(),
            ).order_by(Expense.id.desc())
        ).scalars().first()
        if legacy is None and legacy_title and legacy_amount is not None:
            legacy = db.execute(
                select(Expense).where(
                    Expense.trip_id == stage.trip_id,
                    Expense.stage_id.is_(None),
                    Expense.description == legacy_title,
                    Expense.amount_rub == legacy_amount,
                ).order_by(Expense.id.desc())
            ).scalars().first()
        if legacy is not None:
            legacy.stage_id = stage.id
            legacy.description = stage.title.strip()
            legacy.amount_rub = stage.cost_rub
            legacy.category = category
            return

        existing = Expense(
            trip_id=stage.trip_id,
            stage_id=stage.id,
            description=stage.title.strip(),
            amount_rub=stage.cost_rub,
            category=category,
        )
        db.add(existing)
        return

    existing.description = stage.title.strip()
    existing.amount_rub = stage.cost_rub
    existing.category = category


@router.post(
    "/stage-assistant/transcribe",
    response_model=StageAssistantTranscriptionOut,
)
async def transcribe_stage_audio(
    audio: UploadFile = File(...),
    user_id: int = Depends(get_current_user_id),
):
    del user_id
    content = await audio.read()
    pcm_bytes = _extract_pcm_from_upload(audio, content)
    text = _speechkit_transcribe_lpcm(pcm_bytes)
    return StageAssistantTranscriptionOut(text=text)


@router.post(
    "/stage-assistant/draft",
    response_model=StageAssistantDraftOut,
)
def create_stage_assistant_draft(
    payload: StageAssistantDraftRequest,
    user_id: int = Depends(get_current_user_id),
):
    del user_id
    return _generate_stage_assistant_draft(
        stage_type=payload.stage_type,
        source_text=payload.text,
        route_day=payload.route_day,
    )


@router.post("/", response_model=TripOut)
def create_trip(
    trip: TripCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    if trip.end_date < trip.start_date:
        raise HTTPException(
            status_code=400,
            detail="End date cannot be earlier than start date",
        )

    new_trip = Trip(
        title=trip.title,
        description=trip.description,
        destination_city=trip.destination_city.strip() if trip.destination_city else None,
        start_date=trip.start_date,
        end_date=trip.end_date,
        planned_days=trip.planned_days,
        card_color=_normalize_card_color(trip.card_color),
        card_background=_normalize_card_background(trip.card_background),
        card_icon=_normalize_card_icon(trip.card_icon),
        is_archived=bool(trip.is_archived) if trip.is_archived is not None else False,
        user_id=user_id,
    )
    db.add(new_trip)
    db.commit()
    db.refresh(new_trip)
    return new_trip


def _trip_total_days(start_date, end_date, planned_days) -> int:
    if planned_days and planned_days > 0:
        return int(planned_days)
    return int((end_date - start_date).days + 1)


def _stage_day_index(stage: Stage, trip_start_date) -> int:
    source = stage.start_time or stage.end_time
    if source is None:
        return 0
    stage_day = source.date()
    return max((stage_day - trip_start_date).days, 0)


@router.patch("/{trip_id}", response_model=TripOut)
def update_trip(
    trip_id: int,
    payload: TripUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    trip = _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    next_title = updates.get("title", trip.title)
    next_start = updates.get("start_date", trip.start_date)
    next_end = updates.get("end_date", trip.end_date)
    next_planned_days = updates.get("planned_days", trip.planned_days)
    next_card_color = _normalize_card_color(updates.get("card_color", trip.card_color))
    next_card_background = _normalize_card_background(
        updates.get("card_background", trip.card_background)
    )
    next_card_icon = _normalize_card_icon(updates.get("card_icon", trip.card_icon))
    next_is_archived = updates.get("is_archived", trip.is_archived)

    if next_end < next_start:
        raise HTTPException(
            status_code=400,
            detail="End date cannot be earlier than start date",
        )

    old_total = _trip_total_days(trip.start_date, trip.end_date, trip.planned_days)
    new_total = _trip_total_days(next_start, next_end, next_planned_days)

    if new_total < old_total and not payload.confirm_trim:
        raise HTTPException(
            status_code=409,
            detail=(
                "New period is shorter than previous one. "
                "Tail days and their route data will be deleted. "
                "Resubmit with confirm_trim=true."
            ),
        )

    if new_total < old_total:
        stages = db.execute(
            select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
        ).scalars().all()
        to_delete = [
            stage for stage in stages if _stage_day_index(stage, trip.start_date) >= new_total
        ]
        for stage in to_delete:
            db.delete(stage)
        db.flush()
        remaining = db.execute(
            select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
        ).scalars().all()
        for index, stage in enumerate(remaining):
            stage.position = index

    day_shift = (next_start - trip.start_date).days
    if day_shift != 0:
        stages_to_shift = db.execute(
            select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
        ).scalars().all()
        for stage in stages_to_shift:
            if stage.start_time is not None:
                stage.start_time = stage.start_time + timedelta(days=day_shift)
            if stage.end_time is not None:
                stage.end_time = stage.end_time + timedelta(days=day_shift)

    trip.title = next_title.strip() if isinstance(next_title, str) else trip.title
    trip.start_date = next_start
    trip.end_date = next_end
    trip.planned_days = next_planned_days
    trip.card_color = next_card_color
    trip.card_background = next_card_background
    trip.card_icon = next_card_icon
    trip.is_archived = bool(next_is_archived)

    # Keep date range consistent with mode by days.
    if trip.planned_days and trip.planned_days > 0:
        trip.end_date = trip.start_date + timedelta(days=int(trip.planned_days) - 1)

    db.commit()
    db.refresh(trip)
    return trip


@router.get("/{trip_id}/expenses", response_model=list[ExpenseOut])
def list_expenses(
    trip_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stmt = select(Expense).where(Expense.trip_id == trip_id).order_by(Expense.id.desc())
    return db.execute(stmt).scalars().all()


@router.post("/{trip_id}/expenses", response_model=ExpenseOut, status_code=201)
def create_expense(
    trip_id: int,
    payload: ExpenseCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    allowed_categories = {"food", "housing", "transport", "shopping", "entertainment", "other"}
    category = payload.category.strip().lower()
    if category not in allowed_categories:
        raise HTTPException(status_code=400, detail="Invalid expense category")

    expense = Expense(
        trip_id=trip_id,
        description=payload.description.strip(),
        amount_rub=payload.amount_rub,
        category=category,
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense


@router.patch("/{trip_id}/expenses/{expense_id}", response_model=ExpenseOut)
def update_expense(
    trip_id: int,
    expense_id: int,
    payload: ExpenseUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    expense = _get_trip_expense_or_404(db=db, trip_id=trip_id, expense_id=expense_id)

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    allowed_categories = {"food", "housing", "transport", "shopping", "entertainment", "other"}

    if "description" in updates and updates["description"] is not None:
        updates["description"] = updates["description"].strip()
        if not updates["description"]:
            raise HTTPException(status_code=400, detail="Description is required")

    if "category" in updates and updates["category"] is not None:
        normalized = updates["category"].strip().lower()
        if normalized not in allowed_categories:
            raise HTTPException(status_code=400, detail="Invalid expense category")
        updates["category"] = normalized

    for field_name, value in updates.items():
        setattr(expense, field_name, value)

    db.commit()
    db.refresh(expense)
    return expense


@router.delete("/{trip_id}/expenses/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_expense(
    trip_id: int,
    expense_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    expense = _get_trip_expense_or_404(db=db, trip_id=trip_id, expense_id=expense_id)

    db.delete(expense)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{trip_id}/stages", response_model=list[StageOut])
def list_stages(
    trip_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stmt = select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    return db.execute(stmt).scalars().all()


@router.post("/{trip_id}/stages", response_model=StageOut, status_code=201)
def create_stage(
    trip_id: int,
    payload: StageCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    max_position = db.execute(
        select(Stage.position).where(Stage.trip_id == trip_id).order_by(Stage.position.desc())
    ).scalars().first()
    next_position = (max_position + 1) if max_position is not None else 0

    normalized_type, normalized_subtype = _validate_stage_type_and_subtype(
        payload.stage_type,
        payload.subtype,
    )

    stage = Stage(
        trip_id=trip_id,
        position=next_position,
        stage_type=normalized_type,
        subtype=normalized_subtype,
        title=payload.title.strip(),
        start_location=payload.start_location,
        end_location=payload.end_location,
        address=payload.address,
        latitude=payload.latitude,
        longitude=payload.longitude,
        start_time=payload.start_time,
        end_time=payload.end_time,
        duration_minutes=payload.duration_minutes,
        cost_rub=payload.cost_rub,
        reference_number=payload.reference_number,
        website_url=payload.website_url,
        rating=payload.rating,
        notes=payload.notes,
        document_key=payload.document_key,
    )
    db.add(stage)
    db.flush()
    _create_expense_from_stage_if_needed(stage=stage, db=db)
    db.commit()
    db.refresh(stage)
    return stage


@router.patch("/{trip_id}/stages/{stage_id}", response_model=StageOut)
def update_stage(
    trip_id: int,
    stage_id: int,
    payload: StageUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    updates = payload.model_dump(exclude_unset=True)
    old_title = stage.title.strip() if stage.title else None
    old_category = STAGE_TYPE_TO_EXPENSE_CATEGORY.get(stage.stage_type)
    old_amount = stage.cost_rub

    stage_type = (
        updates.get("stage_type", stage.stage_type)
        if updates.get("stage_type", None) is not None
        else stage.stage_type
    )
    subtype = (
        updates.get("subtype", stage.subtype)
        if updates.get("subtype", None) is not None
        else stage.subtype
    )
    normalized_type, normalized_subtype = _validate_stage_type_and_subtype(stage_type, subtype)
    updates["stage_type"] = normalized_type
    updates["subtype"] = normalized_subtype

    for field_name, value in updates.items():
        if field_name == "title" and isinstance(value, str):
            value = value.strip()
        setattr(stage, field_name, value)

    _sync_stage_expense(
        stage=stage,
        db=db,
        legacy_title=old_title,
        legacy_category=old_category,
        legacy_amount=old_amount,
    )
    db.commit()
    db.refresh(stage)
    return stage


@router.delete("/{trip_id}/stages/{stage_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_stage(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    linked_expense = db.execute(
        select(Expense).where(
            Expense.trip_id == trip_id,
            Expense.stage_id == stage.id,
        )
    ).scalars().first()
    if linked_expense is not None:
        db.delete(linked_expense)
    else:
        if stage.cost_rub is not None:
            legacy = db.execute(
                select(Expense).where(
                    Expense.trip_id == trip_id,
                    Expense.stage_id.is_(None),
                    Expense.description == stage.title.strip(),
                    Expense.amount_rub == stage.cost_rub,
                ).order_by(Expense.id.desc())
            ).scalars().first()
            if legacy is not None:
                db.delete(legacy)

    deleted_position = stage.position
    db.delete(stage)
    db.flush()

    stages_after = db.execute(
        select(Stage).where(Stage.trip_id == trip_id, Stage.position > deleted_position).order_by(Stage.position.asc())
    ).scalars().all()
    for item in stages_after:
        item.position -= 1

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{trip_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    expenses = db.execute(select(Expense).where(Expense.trip_id == trip_id)).scalars().all()
    for expense in expenses:
        db.delete(expense)

    stages = db.execute(select(Stage).where(Stage.trip_id == trip_id)).scalars().all()
    for stage in stages:
        db.delete(stage)

    trip = _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    db.delete(trip)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{trip_id}/stages/{stage_id}/copy", response_model=StageOut, status_code=201)
def copy_stage(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    max_position = db.execute(
        select(Stage.position).where(Stage.trip_id == trip_id).order_by(Stage.position.desc())
    ).scalars().first()
    next_position = (max_position + 1) if max_position is not None else 0

    copied = Stage(
        trip_id=stage.trip_id,
        position=next_position,
        stage_type=stage.stage_type,
        subtype=stage.subtype,
        title=f"{stage.title} (copy)",
        start_location=stage.start_location,
        end_location=stage.end_location,
        address=stage.address,
        latitude=stage.latitude,
        longitude=stage.longitude,
        start_time=stage.start_time,
        end_time=stage.end_time,
        duration_minutes=stage.duration_minutes,
        cost_rub=stage.cost_rub,
        reference_number=stage.reference_number,
        website_url=stage.website_url,
        rating=stage.rating,
        notes=stage.notes,
        document_key=stage.document_key,
    )
    db.add(copied)
    db.commit()
    db.refresh(copied)
    return copied


@router.post("/{trip_id}/stages/reorder", response_model=list[StageOut])
def reorder_stages(
    trip_id: int,
    payload: StageReorderRequest,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)

    current = db.execute(
        select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    ).scalars().all()
    if not current:
        return []

    by_id = {item.id: item for item in current}
    ordered_ids = [stage_id for stage_id in payload.stage_ids if stage_id in by_id]
    tail = [item.id for item in current if item.id not in set(ordered_ids)]
    final_order = ordered_ids + tail

    for index, stage_id in enumerate(final_order):
        by_id[stage_id].position = index

    db.commit()
    return db.execute(
        select(Stage).where(Stage.trip_id == trip_id).order_by(Stage.position.asc(), Stage.id.asc())
    ).scalars().all()


def _fetch_recommendations_for_stage(stage: Stage) -> list[dict]:
    query_params = {
        "stage_type": stage.stage_type,
        "subtype": stage.subtype,
    }
    if stage.end_location:
        query_params["location"] = stage.end_location
    elif stage.start_location:
        query_params["location"] = stage.start_location
    elif stage.address:
        query_params["location"] = stage.address

    if stage.latitude is not None and stage.longitude is not None:
        query_params["latitude"] = str(stage.latitude)
        query_params["longitude"] = str(stage.longitude)

    query = urllib.parse.urlencode(query_params)
    base_url = settings.recommendations_service_url.rstrip("/")
    endpoint = f"{base_url}/recommendations/suggestions?{query}"
    request = urllib.request.Request(endpoint, method="GET")

    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (TimeoutError, urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
        return []

    items = payload.get("items")
    if not isinstance(items, list):
        return []
    return [item for item in items if isinstance(item, dict)]


@router.post("/routing/ors/route", response_model=OrsRouteResponse)
def build_ors_route(payload: OrsRouteRequest):
    api_key = (settings.ors_api_key or "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="ORS routing is not configured")

    mode = payload.mode.strip().lower()
    if mode not in ORS_MODES:
        raise HTTPException(status_code=400, detail="Unsupported routing mode")

    endpoint = f"{settings.ors_base_url.rstrip('/')}/{mode}/geojson"
    body = {
        "coordinates": [[point.lon, point.lat] for point in payload.points],
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": api_key,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise HTTPException(status_code=502, detail=f"ORS request failed: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail="ORS request failed") from exc

    features = data.get("features")
    if not isinstance(features, list) or not features:
        raise HTTPException(status_code=422, detail="Route not found")
    feature = features[0]
    geometry = feature.get("geometry")
    summary = ((feature.get("properties") or {}).get("summary") or {})
    distance = summary.get("distance")
    duration = summary.get("duration")
    if not isinstance(geometry, dict) or distance is None or duration is None:
        raise HTTPException(status_code=422, detail="Invalid ORS route payload")

    return OrsRouteResponse(
        mode=mode,
        distance_m=float(distance),
        duration_s=float(duration),
        geometry=geometry,
    )


@router.get(
    "/{trip_id}/stages/{stage_id}/suggestions",
    response_model=list[StageSuggestionOut],
)
def list_stage_suggestions(
    trip_id: int,
    stage_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user_id),
):
    _get_user_trip_or_404(db=db, trip_id=trip_id, user_id=user_id)
    stage = _get_user_stage_or_404(db=db, trip_id=trip_id, stage_id=stage_id)

    items = _fetch_recommendations_for_stage(stage)
    valid: list[StageSuggestionOut] = []
    for item in items:
        try:
            suggestion = StageSuggestionOut.model_validate(item)
        except Exception:
            continue

        if suggestion.stage_type in STAGE_SUBTYPES and suggestion.subtype in STAGE_SUBTYPES[suggestion.stage_type]:
            valid.append(suggestion)
    return valid
