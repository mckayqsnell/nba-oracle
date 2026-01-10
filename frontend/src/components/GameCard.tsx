import type { Game } from '../types/game'
import { getTeamLogo } from '../utils/teamLogos'

interface GameCardProps {
  game: Game
}

export function GameCard({ game }: GameCardProps) {
  const { home_team, away_team, status, status_text } = game

  const isLive = status === 'in_progress'
  const isFinal = status === 'final'

  // Determine winner for final games
  const homeWon = isFinal && home_team.score > away_team.score
  const awayWon = isFinal && away_team.score > home_team.score

  return (
    <div className="bg-[#1a1a1a] rounded-lg border border-[#2a2a2a] overflow-hidden hover:border-[#3a3a3a] transition-colors">
      {/* Status Bar */}
      <div className="px-4 py-2 border-b border-[#2a2a2a] flex items-center gap-2">
        {isLive && (
          <span className="flex items-center gap-1.5">
            <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
            <span className="text-red-500 text-xs font-semibold uppercase tracking-wider">
              Live
            </span>
          </span>
        )}
        {isFinal && (
          <span className="text-gray-500 text-xs font-semibold uppercase tracking-wider">
            Final
          </span>
        )}
        {!isLive && !isFinal && (
          <span className="text-blue-400 text-xs font-semibold uppercase tracking-wider">
            {status_text}
          </span>
        )}
        {isLive && (
          <span className="text-gray-400 text-xs ml-1">• {status_text}</span>
        )}
      </div>

      {/* Teams */}
      <div className="p-4 space-y-3">
        {/* Away Team */}
        <TeamRow
          team={away_team}
          showScore={isLive || isFinal}
          isWinner={awayWon}
          isLoser={homeWon}
        />

        {/* Home Team */}
        <TeamRow
          team={home_team}
          showScore={isLive || isFinal}
          isWinner={homeWon}
          isLoser={awayWon}
        />
      </div>
    </div>
  )
}

interface TeamRowProps {
  team: {
    abbreviation: string
    city: string
    name: string
    score: number
  }
  showScore: boolean
  isWinner: boolean
  isLoser: boolean
}

function TeamRow({ team, showScore, isWinner, isLoser }: TeamRowProps) {
  return (
    <div className="flex items-center gap-3">
      {/* Logo */}
      <img
        src={getTeamLogo(team.abbreviation)}
        alt={team.name}
        className="w-10 h-10 object-contain"
        onError={(e) => {
          // Hide broken images
          e.currentTarget.style.visibility = 'hidden'
        }}
      />

      {/* Team Name */}
      <div className="flex-1 min-w-0">
        <span
          className={`text-sm font-medium ${
            isLoser ? 'text-gray-500' : 'text-white'
          }`}
        >
          {team.city} <span className="font-semibold">{team.name}</span>
        </span>
      </div>

      {/* Score */}
      {showScore && (
        <span
          className={`text-2xl font-bold tabular-nums ${
            isWinner ? 'text-white' : isLoser ? 'text-gray-500' : 'text-white'
          }`}
        >
          {team.score}
        </span>
      )}
    </div>
  )
}
