from fastapi import FastAPI

app = FastAPI(title="Tour2Tour API")

@app.get("/health")
def health():
    return {"status": "ok"}