"""
Structured logging configuration.

Delegates to sentry-struct-logger (MIT-licensed,
https://github.com/HEAL-Engineering/python-sentry-logger-wrapper) which handles
structlog + Sentry in one shot:

- JSON output to stdout (works with `docker logs` and log aggregators)
- Sentry init when api_env in ("production", "test") AND sentry_dsn is set;
  otherwise it's effectively a no-op, so this same call works in dev
- ERROR-level logs become Sentry events, INFO+ logs become breadcrumbs and
  structured Sentry logs
- Adds trace_id/span_id to every log event for cross-service correlation
"""

import logging

import structlog
from python_sentry_logger_wrapper import get_logger as _configure_logger

from app.settings import settings


def setup_logging() -> None:
    """Configure structlog + Sentry. Idempotent (the package guards reinit)."""
    _configure_logger(
        service_name="nba-oracle",
        log_level=logging.DEBUG if settings.debug else logging.INFO,
        sentry_dsn=settings.sentry_dsn or None,
        sentry_environment=settings.api_env,
        sentry_breadcrumbs_level=logging.INFO,
        sentry_event_level=logging.ERROR,
        sentry_logs_level=settings.sentry_logs_level,
        traces_sample_rate=settings.sentry_traces_sample_rate,
        # "auto" picks ConsoleRenderer under a TTY (running uvicorn directly in
        # a terminal) and JSON otherwise (Docker, CI). No-op for Sentry — it
        # captures at the stdlib handler before the renderer runs.
        renderer="auto",
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def log_api_call(
    logger: structlog.stdlib.BoundLogger,
    *,
    endpoint: str,
    method: str = "GET",
    duration_ms: float | None = None,
    status: str = "success",
    error: str | None = None,
    cached: bool = False,
    **extra: object,
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
    log_data: dict[str, object] = {
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
