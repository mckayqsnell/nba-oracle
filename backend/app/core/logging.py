"""
Structured logging configuration using structlog.

Best practices:
- JSON output in production for log aggregation (ELK, Datadog, etc.)
- Pretty console output in development for readability
- Consistent context (request_id, user_id) across all log entries
- Performance metrics (duration, cache hits) as structured fields
"""

import logging
import sys
from typing import Any

import structlog
from structlog.types import Processor

from app.config import settings


def setup_logging() -> None:
    """
    Configure structlog for the application.

    Development: Pretty, colored console output
    Production: JSON output for log aggregation
    """
    # Shared processors for all environments
    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
    ]

    if settings.debug:
        # Development: colored console output
        processors: list[Processor] = [
            *shared_processors,
            structlog.dev.ConsoleRenderer(colors=True, pad_event=30),
        ]
    else:
        # Production: JSON for log aggregation
        processors = [
            *shared_processors,
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    # Configure standard library logging to use structlog
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.DEBUG if settings.debug else logging.INFO,
    )

    # Suppress noisy third-party loggers
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def log_api_call(
    logger: Any,
    *,
    endpoint: str,
    method: str = "GET",
    duration_ms: float | None = None,
    status: str = "success",
    error: str | None = None,
    cached: bool = False,
    **extra: Any,
) -> None:
    """
    Log an external API call with consistent structure.

    Args:
        logger: The structlog logger instance
        endpoint: API endpoint called (e.g., "box_scores", "games")
        method: HTTP method
        duration_ms: Request duration in milliseconds
        status: "success", "error", "rate_limited"
        error: Error message if failed
        cached: Whether result was served from cache
        **extra: Additional context fields
    """
    log_data = {
        "api": "balldontlie",
        "endpoint": endpoint,
        "method": method,
        "status": status,
        "cached": cached,
        **extra,
    }

    if duration_ms is not None:
        log_data["duration_ms"] = round(duration_ms, 2)

    if error:
        log_data["error"] = error
        logger.warning("external_api_call", **log_data)
    else:
        logger.info("external_api_call", **log_data)
