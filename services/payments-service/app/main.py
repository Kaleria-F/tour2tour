from fastapi import FastAPI

app = FastAPI(title="Tour2Tour Payments Service")


@app.get("/payments/status")
def payment_status():
    return {"status": "stub"}


@app.get("/health")
def health():
    return {"status": "ok"}
