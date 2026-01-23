import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.core.logging import get_logger, setup_logging
from app.routers import games

# Initialize structured logging before app creation
setup_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    logger.info(
        "app_startup",
        environment=settings.api_env,
        debug=settings.debug,
        version="0.1.0",
    )
    yield
    logger.info("app_shutdown")


app = FastAPI(
    title="NBA Oracle API",
    description="ML-powered NBA game predictions",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def logging_middleware(request: Request, call_next) -> Response:
    """Log all HTTP requests with timing and status."""
    start_time = time.perf_counter()

    # Skip logging for health checks (too noisy)
    if request.url.path == "/health":
        return await call_next(request)

    response = await call_next(request)

    duration_ms = (time.perf_counter() - start_time) * 1000

    logger.info(
        "http_request",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=round(duration_ms, 2),
        client_ip=request.client.host if request.client else None,
    )

    return response


app.include_router(games.router, prefix="/api/games", tags=["games"])


@app.get("/")
async def root():
    """API root endpoint - returns basic API information."""
    return {
        "name": "NBA Oracle API",
        "version": "0.1.0",
        "status": "ok",
        "docs": "/docs",
    }


@app.get("/favicon.ico", status_code=204)
async def favicon():
    """Return empty response for favicon requests."""
    return Response(status_code=204)


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring and load balancers."""
    return {"status": "healthy", "environment": settings.api_env}
