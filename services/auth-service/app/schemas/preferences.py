from pydantic import BaseModel, Field


class PreferencesBase(BaseModel):
    interests: list[str] = Field(default_factory=list)


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


class SurveyProfileOut(SurveyProfileIn):
    has_completed: bool = False
