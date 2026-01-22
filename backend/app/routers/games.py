"""
Games router - HTTP endpoints for game data.
"""

from fastapi import APIRouter, Depends, HTTPException

from app.core.security import verify_api_key
from app.models.schemas import GameListResponse
from app.services.game_service import GameServiceDep

# All routes in this router require API key authentication
router = APIRouter(
    dependencies=[Depends(verify_api_key)],
)


@router.get("/today", response_model=GameListResponse)
async def get_todays_games(service: GameServiceDep):
    """
    Get today's NBA games with live scores.

    Returns games sorted by status: live first, then scheduled, then final.
    Scores update on each request - frontend should poll every 30 seconds.
    """
    try:
        return service.get_todays_games()
    except ValueError as e:
        # Missing API key
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch games from NBA API: {e!s}",
        )
