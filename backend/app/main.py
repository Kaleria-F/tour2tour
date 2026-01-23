from fastapi import FastAPI
from fastapi.security import HTTPBearer
from app.api.auth import router as auth_router
from app.api.users import router as users_router
from app.api import trips

app = FastAPI(
    title="Tour2Tour API",
    swagger_ui_parameters={"persistAuthorization": True},
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(trips.router)

@app.get("/health")
def health():
    return {"status": "ok"}
