from pydantic import BaseModel, Field


class PreferencesBase(BaseModel):
    interests: list[str] = Field(default_factory=list)


class PreferencesUpsert(PreferencesBase):
    pass


class PreferencesOut(PreferencesBase):
    pass
