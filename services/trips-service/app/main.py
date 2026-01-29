from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.trips import router as trips_router

app = FastAPI(title="Tour2Tour Trips Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(trips_router)


@app.get("/health")
def health():
    return {"status": "ok"}
