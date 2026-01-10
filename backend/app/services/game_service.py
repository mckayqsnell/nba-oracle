"""
Game service - business logic for fetching and transforming game data.

Caching Strategy:
- 5 second TTL balances freshness with API efficiency
- 60 req/min limit = 1 req/sec max, so 5s TTL uses only 12 req/min (20% of limit)
- Stale cache returned on API errors for resilience
"""

from datetime import UTC, datetime
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import Depends

from app.core.logging import get_logger
from app.models.schemas import Game, GameListResponse, GameStatus, Team
from app.providers.balldontlie_provider import (
    BalldontlieProvider,
    BalldontlieProviderDep,
)

logger = get_logger(__name__)

# NBA schedules use US Eastern time
US_EASTERN = ZoneInfo("America/New_York")

# Cache configuration
# With 60 req/min limit, 5s TTL = 12 req/min max (20% of limit) - plenty of headroom
_games_cache: GameListResponse | None = None
_cache_timestamp: datetime | None = None
CACHE_TTL_SECONDS = 5


class GameService:
    """Handles game-related business logic."""

    def __init__(self, provider: BalldontlieProvider):
        self._provider = provider

    def get_todays_games(self) -> GameListResponse:
        """Get all games scheduled for today with current scores."""
        global _games_cache, _cache_timestamp

        now = datetime.now(UTC)

        # Return cached data if still valid
        if (
            _games_cache is not None
            and _cache_timestamp is not None
            and (now - _cache_timestamp).total_seconds() < CACHE_TTL_SECONDS
        ):
            cache_age_ms = (now - _cache_timestamp).total_seconds() * 1000
            logger.debug(
                "cache_hit",
                cache_age_ms=round(cache_age_ms, 2),
                game_count=len(_games_cache.games),
            )
            return _games_cache

        # Use US Eastern time for date (NBA schedule timezone)
        eastern_now = datetime.now(US_EASTERN)
        today = eastern_now.date()

        logger.info(
            "fetching_games",
            date=today.isoformat(),
            eastern_time=eastern_now.strftime("%H:%M:%S"),
        )

        # Try to fetch fresh data
        try:
            # Try box scores first (has live scores), fall back to games
            try:
                response = self._provider.fetch_box_scores_by_date(today)
                games = [self._transform_box_score(g) for g in response.data]
                data_source = "box_scores"
            except Exception as box_err:
                logger.warning(
                    "box_scores_fallback",
                    error_type=type(box_err).__name__,
                    error_message=str(box_err),
                )
                # Fall back to games endpoint
                response = self._provider.fetch_games_by_date(today)
                games = [self._transform_game(g) for g in response.data]
                data_source = "games"

            # Count game statuses for logging
            live_count = sum(1 for g in games if g.status == GameStatus.IN_PROGRESS)
            scheduled_count = sum(1 for g in games if g.status == GameStatus.SCHEDULED)
            final_count = sum(1 for g in games if g.status == GameStatus.FINAL)

            # Sort: live games first, then scheduled, then final
            games.sort(
                key=lambda g: (
                    0
                    if g.status == GameStatus.IN_PROGRESS
                    else 1
                    if g.status == GameStatus.SCHEDULED
                    else 2
                )
            )

            result = GameListResponse(games=games, last_updated=now)

            # Update cache
            _games_cache = result
            _cache_timestamp = now

            logger.info(
                "games_fetched",
                data_source=data_source,
                total_games=len(games),
                live_games=live_count,
                scheduled_games=scheduled_count,
                final_games=final_count,
            )

            return result

        except Exception as e:
            error_type = type(e).__name__
            logger.error(
                "fetch_games_failed",
                error_type=error_type,
                error_message=str(e),
                has_cache=_games_cache is not None,
            )
            # Return stale cache if available
            if _games_cache is not None:
                cache_age_s = (
                    (now - _cache_timestamp).total_seconds()
                    if _cache_timestamp
                    else None
                )
                logger.warning(
                    "returning_stale_cache",
                    cache_age_seconds=round(cache_age_s, 1) if cache_age_s else None,
                    game_count=len(_games_cache.games),
                )
                return _games_cache
            # Re-raise if no cache available
            raise

    def _transform_box_score(self, box_score) -> Game:
        """Transform box score object to our Game model (has live scores)."""
        status = self._parse_status(getattr(box_score, "status", "") or "")

        # Box scores have home_team and visitor_team with nested data
        home = box_score.home_team
        visitor = box_score.visitor_team

        return Game(
            id=getattr(box_score, "id", 0) or hash(f"{home.id}-{visitor.id}"),
            status=status,
            status_text=self._format_box_score_status(box_score, status),
            period=getattr(box_score, "period", 0) or 0,
            time_remaining=getattr(box_score, "time", None),
            home_team=Team(
                id=home.id,
                name=home.name,
                city=home.city,
                abbreviation=home.abbreviation,
                score=getattr(box_score, "home_team_score", 0) or 0,
            ),
            away_team=Team(
                id=visitor.id,
                name=visitor.name,
                city=visitor.city,
                abbreviation=visitor.abbreviation,
                score=getattr(box_score, "visitor_team_score", 0) or 0,
            ),
            start_time=self._parse_datetime(getattr(box_score, "datetime", None)),
        )

    def _format_box_score_status(self, box_score, status: GameStatus) -> str:
        """Format status text for box score data."""
        if status == GameStatus.FINAL:
            return "Final"
        elif status == GameStatus.IN_PROGRESS:
            period = getattr(box_score, "period", 0) or 0
            time_remaining = getattr(box_score, "time", "") or ""
            period_name = self._get_period_name(period)
            return f"{period_name} {time_remaining}".strip()
        else:
            # Scheduled
            raw_status = getattr(box_score, "status", "")
            dt = self._parse_datetime(raw_status)
            if dt:
                # Convert to Eastern time for display
                et_time = dt.astimezone(US_EASTERN)
                return et_time.strftime("%-I:%M %p ET")
            return "TBD"

    def _transform_game(self, game) -> Game:
        """Transform SDK game object to our Game model."""
        status = self._parse_status(getattr(game, "status", "") or "")

        return Game(
            id=game.id,
            status=status,
            status_text=self._format_status_text(game, status),
            period=getattr(game, "period", 0) or 0,
            time_remaining=getattr(game, "time", None),
            home_team=Team(
                id=game.home_team.id,
                name=game.home_team.name,
                city=game.home_team.city,
                abbreviation=game.home_team.abbreviation,
                score=getattr(game, "home_team_score", 0) or 0,
            ),
            away_team=Team(
                id=game.visitor_team.id,
                name=game.visitor_team.name,
                city=game.visitor_team.city,
                abbreviation=game.visitor_team.abbreviation,
                score=getattr(game, "visitor_team_score", 0) or 0,
            ),
            start_time=self._parse_datetime(getattr(game, "datetime", None))
            or self._parse_datetime(getattr(game, "status", None)),
        )

    def _parse_status(self, status_str: str) -> GameStatus:
        """Parse API status string to our enum."""
        status_lower = status_str.lower()
        if "final" in status_lower:
            return GameStatus.FINAL
        elif "qtr" in status_lower or "half" in status_lower or "ot" in status_lower:
            return GameStatus.IN_PROGRESS
        else:
            # Scheduled games may have datetime in status field or "scheduled" text
            return GameStatus.SCHEDULED

    def _format_status_text(self, game, status: GameStatus) -> str:
        """Format human-readable status text."""
        if status == GameStatus.FINAL:
            return "Final"
        elif status == GameStatus.IN_PROGRESS:
            period = getattr(game, "period", 0) or 0
            time_remaining = getattr(game, "time", "") or ""
            period_name = self._get_period_name(period)
            return f"{period_name} {time_remaining}".strip()
        else:
            # Scheduled - try datetime field first, then status field (API returns datetime there)
            dt = self._parse_datetime(getattr(game, "datetime", None))
            if not dt:
                # API sometimes puts datetime in status field for scheduled games
                dt = self._parse_datetime(getattr(game, "status", None))
            if dt:
                # Convert to Eastern time for display
                et_time = dt.astimezone(US_EASTERN)
                return et_time.strftime("%-I:%M %p ET")
            return "TBD"

    def _get_period_name(self, period: int) -> str:
        """Convert period number to display name."""
        if period <= 4:
            suffixes = {1: "1st", 2: "2nd", 3: "3rd", 4: "4th"}
            return suffixes.get(period, f"{period}th")
        else:
            ot_num = period - 4
            return f"OT{ot_num}" if ot_num > 1 else "OT"

    def _parse_datetime(self, dt_value) -> datetime | None:
        """Parse datetime from API - handles both string and datetime objects."""
        if dt_value is None:
            return None
        # SDK might return datetime object directly
        if isinstance(dt_value, datetime):
            return dt_value
        # Or it might be a string
        if isinstance(dt_value, str):
            try:
                return datetime.fromisoformat(dt_value.replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                return None
        return None


def get_game_service(provider: BalldontlieProviderDep) -> GameService:
    """Factory for GameService with injected provider."""
    return GameService(provider)


# Type alias for cleaner router signatures
GameServiceDep = Annotated[GameService, Depends(get_game_service)]
