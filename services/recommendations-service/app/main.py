from fastapi import FastAPI

app = FastAPI(title="Tour2Tour Recommendations Service")


@app.get("/recommendations")
def list_recommendations():
    return {"items": []}


@app.get("/health")
def health():
    return {"status": "ok"}
