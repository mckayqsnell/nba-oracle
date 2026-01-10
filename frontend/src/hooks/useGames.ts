import { useState, useEffect, useCallback } from 'react'
import type { Game } from '../types/game'
import { fetchTodaysGames } from '../api/games'

const POLL_INTERVAL_MS = 30_000 // 30 seconds

interface UseGamesResult {
  games: Game[]
  isLoading: boolean
  error: string | null
  lastUpdated: Date | null
  refresh: () => Promise<void>
}

export function useGames(): UseGamesResult {
  const [games, setGames] = useState<Game[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)

  const refresh = useCallback(async () => {
    try {
      const response = await fetchTodaysGames()
      setGames(response.games)
      setLastUpdated(new Date(response.last_updated))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load games')
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    // Initial fetch
    refresh()

    // Set up polling for live updates
    const interval = setInterval(refresh, POLL_INTERVAL_MS)

    return () => clearInterval(interval)
  }, [refresh])

  return { games, isLoading, error, lastUpdated, refresh }
}
