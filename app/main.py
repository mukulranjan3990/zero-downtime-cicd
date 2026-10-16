
from fastapi import FastAPI

app = FastAPI(
    title="Zero-Downtime CI/CD API",
    version="1.0.0",
)


@app.get("/")
def home():
    return {
        "message": "Zero-Downtime CI/CD Pipeline API",
        "status": "running",
    }


@app.get("/healthz")
def health_check():
    return {
        "status": "healthy",
    }
