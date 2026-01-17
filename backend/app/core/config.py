from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    jwt_secret: str = "change_me"
    jwt_alg: str = "HS256"

    class Config:
        env_file = ".env"

settings = Settings()
