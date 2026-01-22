import type { VercelRequest, VercelResponse } from '@vercel/node'

const BACKEND_URL = process.env.BACKEND_URL || 'https://api.nbaoracle.com'

export default async function handler(
  request: VercelRequest,
  response: VercelResponse
) {
  if (request.method !== 'GET') {
    return response.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const backendResponse = await fetch(`${BACKEND_URL}/health`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
    })

    if (!backendResponse.ok) {
      return response.status(backendResponse.status).json({
        frontend: 'ok',
        backend: 'error',
        backend_status: backendResponse.status,
      })
    }

    const backendHealth = await backendResponse.json()

    return response.status(200).json({
      frontend: 'ok',
      backend: backendHealth,
    })
  } catch (error) {
    return response.status(200).json({
      frontend: 'ok',
      backend: 'unreachable',
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
}
