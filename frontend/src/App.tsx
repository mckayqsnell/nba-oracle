import { TodaysGames } from './components/TodaysGames'

function App() {
  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  })

  return (
    <div className="min-h-screen bg-[#0f0f0f] text-white">
      {/* Header */}
      <header className="border-b border-[#2a2a2a]">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold">NBA Oracle</h1>
          <p className="text-gray-400 mt-1">ML-powered game predictions</p>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <h2 className="text-xl font-semibold">Today's Games</h2>
          <p className="text-gray-500 text-sm">{today}</p>
        </div>

        <TodaysGames />
      </main>

      {/* Footer */}
      <footer className="border-t border-[#2a2a2a] mt-auto">
        <div className="container mx-auto px-4 py-4">
          <p className="text-gray-600 text-sm text-center">
            Scores update every 2 seconds during live games
          </p>
        </div>
      </footer>
    </div>
  )
}

export default App
