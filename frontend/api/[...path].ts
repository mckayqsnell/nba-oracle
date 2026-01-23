import type { VercelRequest, VercelResponse } from '@vercel/node'

const BACKEND_URL = process.env.BACKEND_URL || 'https://api.nbaoracle.com'
const API_KEY = process.env.API_KEY

// =============================================================================
// Endpoint Configuration
// =============================================================================
// Define custom behavior for specific endpoints. Any endpoint not listed here
// uses the default config (proxy with API key, 30s cache).
//
// Future options you could add:
// - requireAuth: boolean - require additional user auth
// - rateLimit: number - requests per minute
// - transform: (data) => data - modify response before returning
// =============================================================================

type EndpointConfig = {
  /** Cache duration in seconds (s-maxage). Default: 30 */
  cacheDuration?: number
  /** Stale-while-revalidate duration. Default: 60 */
  staleWhileRevalidate?: number
  /** Skip API key header (for public endpoints). Default: false */
  skipApiKey?: boolean
  /** Allowed HTTP methods. Default: ['GET'] */
  methods?: string[]
  /** Custom handler - completely override default proxy behavior */
  handler?: (req: VercelRequest, res: VercelResponse) => Promise<void>
}

const endpointConfig: Record<string, EndpointConfig> = {
  // Games endpoint - shorter cache for live scores
  'games/today': {
    cacheDuration: 30,
    staleWhileRevalidate: 60,
  },

  // Health check - no caching, no API key needed
  health: {
    cacheDuration: 0,
    skipApiKey: true,
  },

  // Example: Future protected endpoint
  // 'admin/stats': {
  //   requireAuth: true,  // You'd implement this check
  //   methods: ['GET', 'POST'],
  // },
}

// =============================================================================
// Default Configuration
// =============================================================================

const defaultConfig: Required<Omit<EndpointConfig, 'handler'>> = {
  cacheDuration: 30,
  staleWhileRevalidate: 60,
  skipApiKey: false,
  methods: ['GET'],
}

// =============================================================================
// Catch-All Handler
// =============================================================================

export default async function handler(
  request: VercelRequest,
  response: VercelResponse
) {
  // Extract the path from the catch-all parameter
  const { path } = request.query
  const pathString = Array.isArray(path) ? path.join('/') : path || ''

  // Get endpoint-specific config or use defaults
  const config = { ...defaultConfig, ...endpointConfig[pathString] }

  // Check if custom handler exists
  if (endpointConfig[pathString]?.handler) {
    return endpointConfig[pathString].handler!(request, response)
  }

  // Method validation
  if (!config.methods.includes(request.method || 'GET')) {
    return response.status(405).json({ error: 'Method not allowed' })
  }

  try {
    // Build headers
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }

    if (!config.skipApiKey && API_KEY) {
      headers['X-API-Key'] = API_KEY
    }

    // Proxy to backend
    const backendUrl = `${BACKEND_URL}/api/${pathString}`
    const backendResponse = await fetch(backendUrl, {
      method: request.method,
      headers,
      body: request.method !== 'GET' ? JSON.stringify(request.body) : undefined,
    })

    if (!backendResponse.ok) {
      const errorText = await backendResponse.text()
      console.error(
        `Backend error [${pathString}]:`,
        backendResponse.status,
        errorText
      )
      return response.status(backendResponse.status).json({
        error: 'Backend request failed',
        status: backendResponse.status,
        path: pathString,
      })
    }

    const data = await backendResponse.json()

    // Set cache headers
    if (config.cacheDuration > 0) {
      response.setHeader(
        'Cache-Control',
        `s-maxage=${config.cacheDuration}, stale-while-revalidate=${config.staleWhileRevalidate}`
      )
    } else {
      response.setHeader('Cache-Control', 'no-store')
    }

    return response.status(200).json(data)
  } catch (error) {
    console.error(`Proxy error [${pathString}]:`, error)
    return response.status(500).json({
      error: 'Internal server error',
      path: pathString,
    })
  }
}
