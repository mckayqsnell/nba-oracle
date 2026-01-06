import { useEffect, useState } from 'react'

interface HealthStatus {
  status: string
  environment: string
}

function App() {
  const [health, setHealth] = useState<HealthStatus | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch('/health')
      .then(res => res.json())
      .then(data => setHealth(data))
      .catch(() => setError('Unable to connect to API'))
  }, [])

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <div className="container mx-auto px-4 py-16">
        <h1 className="text-5xl font-bold text-center mb-8">
          NBA Oracle
        </h1>
        <p className="text-xl text-gray-400 text-center mb-12">
          ML-powered NBA game predictions
        </p>

        <div className="max-w-md mx-auto bg-gray-800 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-4">API Status</h2>
          {error ? (
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 bg-red-500 rounded-full"></span>
              <span className="text-red-400">{error}</span>
            </div>
          ) : health ? (
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 bg-green-500 rounded-full"></span>
              <span className="text-green-400">
                Connected ({health.environment})
              </span>
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 bg-yellow-500 rounded-full animate-pulse"></span>
              <span className="text-yellow-400">Connecting...</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
