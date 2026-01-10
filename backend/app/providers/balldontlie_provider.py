"""
Provider for balldontlie.io NBA API.
Handles raw API communication only - no business logic.

Rate Limits (as of 2024):
- Free tier: 60 requests/minute
- Paid tiers: higher limits available
"""

import time
from datetime import date
from functools import lru_cache
from typing import Annotated

from balldontlie import BalldontlieAPI
from fastapi import Depends

from app.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Rate limit tracking (for visibility, not enforcement)
RATE_LIMIT_PER_MINUTE = 60


class BalldontlieProvider:
    """Low-level API client for balldontlie.io with comprehensive logging."""

    def __init__(self, api: BalldontlieAPI):
        self._api = api

    def fetch_games_by_date(self, game_date: date):
        """Fetch scheduled games for a specific date."""
        start_time = time.perf_counter()
        endpoint = "games.list"

        logger.debug(
            "api_request_start",
            endpoint=endpoint,
            date=game_date.isoformat(),
        )

        try:
            response = self._api.nba.games.list(dates=[game_date.isoformat()])
            duration_ms = (time.perf_counter() - start_time) * 1000
            game_count = len(response.data) if hasattr(response, "data") else 0

            logger.info(
                "api_request_success",
                endpoint=endpoint,
                date=game_date.isoformat(),
                duration_ms=round(duration_ms, 2),
                game_count=game_count,
            )
            return response

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            error_type = type(e).__name__

            logger.error(
                "api_request_failed",
                endpoint=endpoint,
                date=game_date.isoformat(),
                duration_ms=round(duration_ms, 2),
                error_type=error_type,
                error_message=str(e),
            )
            raise

    def fetch_box_scores_by_date(self, game_date: date):
        """Fetch box scores for a specific date (includes live scores)."""
        start_time = time.perf_counter()
        endpoint = "box_scores.get_by_date"

        logger.debug(
            "api_request_start",
            endpoint=endpoint,
            date=game_date.isoformat(),
        )

        try:
            response = self._api.nba.box_scores.get_by_date(date=game_date.isoformat())
            duration_ms = (time.perf_counter() - start_time) * 1000
            game_count = len(response.data) if hasattr(response, "data") else 0

            logger.info(
                "api_request_success",
                endpoint=endpoint,
                date=game_date.isoformat(),
                duration_ms=round(duration_ms, 2),
                game_count=game_count,
            )
            return response

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            error_type = type(e).__name__

            logger.error(
                "api_request_failed",
                endpoint=endpoint,
                date=game_date.isoformat(),
                duration_ms=round(duration_ms, 2),
                error_type=error_type,
                error_message=str(e),
            )
            raise

    def fetch_live_box_scores(self):
        """Fetch live box scores for games currently in progress."""
        start_time = time.perf_counter()
        endpoint = "box_scores.get_live"

        logger.debug("api_request_start", endpoint=endpoint)

        try:
            response = self._api.nba.box_scores.get_live()
            duration_ms = (time.perf_counter() - start_time) * 1000
            game_count = len(response.data) if hasattr(response, "data") else 0

            logger.info(
                "api_request_success",
                endpoint=endpoint,
                duration_ms=round(duration_ms, 2),
                game_count=game_count,
            )
            return response

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            error_type = type(e).__name__

            logger.error(
                "api_request_failed",
                endpoint=endpoint,
                duration_ms=round(duration_ms, 2),
                error_type=error_type,
                error_message=str(e),
            )
            raise


@lru_cache
def get_balldontlie_api() -> BalldontlieAPI:
    """
    App-wide singleton for the balldontlie API client.
    Cached to reuse HTTP connection pool across requests.
    """
    if not settings.balldontlie_api_key:
        raise ValueError(
            "BALLDONTLIE_API_KEY not set. "
            "Add it to 1Password (local section) and run 'task env'"
        )
    return BalldontlieAPI(api_key=settings.balldontlie_api_key)


def get_balldontlie_provider(
    api: Annotated[BalldontlieAPI, Depends(get_balldontlie_api)],
) -> BalldontlieProvider:
    """Factory for BalldontlieProvider with injected API client."""
    return BalldontlieProvider(api)


# Type alias for cleaner router signatures
BalldontlieProviderDep = Annotated[
    BalldontlieProvider, Depends(get_balldontlie_provider)
]
