from pydantic import BaseModel, Field, field_validator

INTEREST_TAGS = {
    "history",
    "culture",
    "museums",
    "architecture",
    "nature",
    "food",
    "active",
    "shopping",
    "photo",
    "nightlife",
    "hidden",
    "family",
    "walk",
}

TRIP_FORMAT_TAGS = {
    "calm",
    "active_format",
    "intense",
    "romantic",
    "friends",
    "solo",
    "city",
    "weekend",
}

TRAVEL_MODE_TAGS = {
    "solo",
    "couple",
    "friends",
    "family",
    "walk",
}

PACE_VALUES = {
    "slow",
    "medium",
    "intense",
}


class PreferencesBase(BaseModel):
    interests: list[str] = Field(default_factory=list)

    @field_validator("interests")
    @classmethod
    def validate_interests(cls, value: list[str]) -> list[str]:
        invalid = sorted({item for item in value if item not in INTEREST_TAGS})
        if invalid:
            raise ValueError(f"Unknown interest tags: {', '.join(invalid)}")
        return value


class PreferencesUpsert(PreferencesBase):
    pass


class PreferencesOut(PreferencesBase):
    pass


class SurveyProfileIn(BaseModel):
    interests: list[str] = Field(default_factory=list)
    trip_formats: list[str] = Field(default_factory=list)
    budget: str | None = None
    travel_mode: str | None = None
    pace: str | None = None
    interest_weights: dict[str, int] = Field(default_factory=dict)
    skipped: bool = False

    @field_validator("interests")
    @classmethod
    def validate_interest_tags(cls, value: list[str]) -> list[str]:
        invalid = sorted({item for item in value if item not in INTEREST_TAGS})
        if invalid:
            raise ValueError(f"Unknown interest tags: {', '.join(invalid)}")
        return value

    @field_validator("trip_formats")
    @classmethod
    def validate_trip_formats(cls, value: list[str]) -> list[str]:
        invalid = sorted({item for item in value if item not in TRIP_FORMAT_TAGS})
        if invalid:
            raise ValueError(f"Unknown trip format tags: {', '.join(invalid)}")
        return value

    @field_validator("travel_mode")
    @classmethod
    def validate_travel_mode(cls, value: str | None) -> str | None:
        if value is None or value in TRAVEL_MODE_TAGS:
            return value
        raise ValueError(f"Unknown travel mode: {value}")

    @field_validator("pace")
    @classmethod
    def validate_pace(cls, value: str | None) -> str | None:
        if value is None or value in PACE_VALUES:
            return value
        raise ValueError(f"Unknown pace: {value}")

    @field_validator("interest_weights")
    @classmethod
    def validate_interest_weights(cls, value: dict[str, int]) -> dict[str, int]:
        invalid_keys = sorted({key for key in value if key not in INTEREST_TAGS})
        if invalid_keys:
            raise ValueError(f"Unknown interest weight tags: {', '.join(invalid_keys)}")
        invalid_weights = sorted(
            f"{key}={weight}"
            for key, weight in value.items()
            if not isinstance(weight, int) or weight < 1 or weight > 5
        )
        if invalid_weights:
            raise ValueError(f"Interest weights must be integers from 1 to 5: {', '.join(invalid_weights)}")
        return value


class SurveyProfileOut(SurveyProfileIn):
    has_completed: bool = False
