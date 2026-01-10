import { useGames } from '../hooks/useGames'
import { GameCard } from './GameCard'

export function TodaysGames() {
  const { games, isLoading, error, lastUpdated, refresh } = useGames()

  if (isLoading) {
    return <LoadingSkeleton />
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-400 mb-4">{error}</p>
        <button
          onClick={refresh}
          className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-medium transition-colors"
        >
          Try Again
        </button>
      </div>
    )
  }

  if (games.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-400 text-lg">No games scheduled for today</p>
        <p className="text-gray-500 text-sm mt-2">Check back tomorrow!</p>
      </div>
    )
  }

  return (
    <div>
      {/* Last Updated */}
      {lastUpdated && (
        <p className="text-gray-500 text-xs mb-4 text-right">
          Updated {lastUpdated.toLocaleTimeString()}
        </p>
      )}

      {/* Games Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {games.map((game) => (
          <GameCard key={game.id} game={game} />
        ))}
      </div>
    </div>
  )
}

function LoadingSkeleton() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {[1, 2, 3].map((i) => (
        <div
          key={i}
          className="bg-[#1a1a1a] rounded-lg border border-[#2a2a2a] h-40 animate-pulse"
        />
      ))}
    </div>
  )
}
