from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.documents import router as documents_router
from app.core.config import settings
from app.db.base import Base
from app.db.session import engine
from app.models.document import Document  # noqa: F401

app = FastAPI(title="Tour2Tour Documents Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.s3_cors_allowed_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(documents_router)


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}
