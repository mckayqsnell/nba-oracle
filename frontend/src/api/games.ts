import type { GameListResponse } from '../types/game'

const API_BASE = '/api'

export async function fetchTodaysGames(): Promise<GameListResponse> {
  const response = await fetch(`${API_BASE}/games/today`)

  if (!response.ok) {
    throw new Error(`Failed to fetch games: ${response.statusText}`)
  }

  return response.json()
}
