export type GameStatus = 'scheduled' | 'in_progress' | 'final'

export interface Team {
  id: number
  name: string
  city: string
  abbreviation: string
  score: number
}

export interface Game {
  id: number
  status: GameStatus
  status_text: string
  period: number
  time_remaining: string | null
  home_team: Team
  away_team: Team
  start_time: string | null
}

export interface GameListResponse {
  games: Game[]
  last_updated: string
}
