import httpx


class NBAApiService:
    """Service for fetching NBA data from external APIs."""

    def __init__(self):
        self.client = httpx.AsyncClient()

    async def get_todays_games(self) -> list[dict]:
        """Fetch today's games from NBA API."""
        # Placeholder for real NBA API integration
        # Will be implemented with actual API calls
        return []

    async def close(self):
        await self.client.aclose()
