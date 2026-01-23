import type { GameListResponse } from '../types/game'

// In production, use the full API URL. In dev, use relative path (Vite proxies it)
const API_BASE = import.meta.env.VITE_API_URL || '/api'

export async function fetchTodaysGames(): Promise<GameListResponse> {
  const response = await fetch(`${API_BASE}/games/today`)

  if (!response.ok) {
    throw new Error(`Failed to fetch games: ${response.statusText}`)
  }

  return response.json()
}
