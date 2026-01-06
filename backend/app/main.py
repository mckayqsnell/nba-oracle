from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import games

app = FastAPI(
    title="NBA Oracle API",
    description="ML-powered NBA game predictions",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(games.router, prefix="/api/games", tags=["games"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "environment": settings.api_env}
