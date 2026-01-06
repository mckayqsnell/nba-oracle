from fastapi import APIRouter

from app.models.schemas import Game, Prediction

router = APIRouter()


@router.get("/today", response_model=list[Game])
async def get_todays_games():
    """Get today's NBA games with predictions."""
    # Mock data for initial setup
    return [
        Game(
            id="1",
            home_team="Los Angeles Lakers",
            away_team="Boston Celtics",
            game_time="2024-01-15T19:30:00Z",
            prediction=Prediction(
                winner="Los Angeles Lakers",
                confidence=0.65,
                spread=-3.5,
            ),
        ),
        Game(
            id="2",
            home_team="Golden State Warriors",
            away_team="Phoenix Suns",
            game_time="2024-01-15T22:00:00Z",
            prediction=Prediction(
                winner="Phoenix Suns",
                confidence=0.58,
                spread=2.5,
            ),
        ),
    ]
