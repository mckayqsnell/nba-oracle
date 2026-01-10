from datetime import datetime
from enum import Enum

from pydantic import BaseModel


class GameStatus(str, Enum):
    SCHEDULED = "scheduled"
    IN_PROGRESS = "in_progress"
    FINAL = "final"


class Team(BaseModel):
    id: int
    name: str
    city: str
    abbreviation: str
    score: int


class Game(BaseModel):
    id: int
    status: GameStatus
    status_text: str  # "7:30 PM ET", "3rd Qtr 4:32", "Final"
    period: int
    time_remaining: str | None  # "4:32" or None
    home_team: Team
    away_team: Team
    start_time: datetime | None


class GameListResponse(BaseModel):
    games: list[Game]
    last_updated: datetime


# For predictions later
class Prediction(BaseModel):
    winner_id: int
    confidence: float
    spread: float


class GameWithPrediction(Game):
    prediction: Prediction | None = None
