import { useState, useEffect, useCallback, useRef } from 'react'
import type { Game } from '../types/game'
import { fetchTodaysGames } from '../api/games'

// Polling intervals based on game state
const POLL_LIVE_MS = 5_000 // 5s when games are in progress
const POLL_STARTING_SOON_MS = 30_000 // 30s when games starting within 30 min
const POLL_SCHEDULED_MS = 60_000 // 1min when games scheduled but not soon
const POLL_ALL_FINAL_MS = 300_000 // 5min when all games are done

// TODO: Consider migrating to TanStack Query for more sophisticated data fetching.
// It has built-in support for dynamic refetchInterval via a function callback.
// See: https://tanstack.com/query/v5/docs/framework/react/guides/query-retries

function getPollingInterval(games: Game[]): number {
  // If any game is live, poll frequently
  const hasLiveGames = games.some((g) => g.status === 'in_progress')
  if (hasLiveGames) return POLL_LIVE_MS

  // If games are starting soon (within 30 min), poll moderately
  const hasUpcomingGames = games.some((g) => {
    if (g.status !== 'scheduled' || !g.start_time) return false
    const startTime = new Date(g.start_time)
    const minutesUntilStart = (startTime.getTime() - Date.now()) / 60_000
    return minutesUntilStart > 0 && minutesUntilStart <= 30
  })
  if (hasUpcomingGames) return POLL_STARTING_SOON_MS

  // If all games are final, poll infrequently
  const allFinal = games.length > 0 && games.every((g) => g.status === 'final')
  if (allFinal) return POLL_ALL_FINAL_MS

  // Default: games scheduled but not starting soon
  return POLL_SCHEDULED_MS
}

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
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

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

  // Set up adaptive polling based on game state
  useEffect(() => {
    // Initial fetch
    refresh()

    // Start with default interval, will adjust after first fetch
    const currentInterval = getPollingInterval(games)
    intervalRef.current = setInterval(refresh, currentInterval)

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
    }
  }, [refresh]) // eslint-disable-line react-hooks/exhaustive-deps

  // Adjust polling interval when games state changes
  useEffect(() => {
    if (isLoading) return // Don't adjust during initial load

    const newInterval = getPollingInterval(games)

    // Clear existing interval and set new one
    if (intervalRef.current) clearInterval(intervalRef.current)
    intervalRef.current = setInterval(refresh, newInterval)

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
    }
  }, [games, isLoading, refresh])

  return { games, isLoading, error, lastUpdated, refresh }
}
