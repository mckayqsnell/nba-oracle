from pydantic import BaseModel


class Prediction(BaseModel):
    winner: str
    confidence: float
    spread: float


class Game(BaseModel):
    id: str
    home_team: str
    away_team: str
    game_time: str
    prediction: Prediction | None = None
