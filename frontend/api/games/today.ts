import type { VercelRequest, VercelResponse } from '@vercel/node'

const BACKEND_URL = process.env.BACKEND_URL || 'https://api.nbaoracle.com'
const API_KEY = process.env.API_KEY

export default async function handler(
  request: VercelRequest,
  response: VercelResponse
) {
  // Only allow GET requests
  if (request.method !== 'GET') {
    return response.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const backendResponse = await fetch(`${BACKEND_URL}/api/games/today`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(API_KEY && { 'X-API-Key': API_KEY }),
      },
    })

    if (!backendResponse.ok) {
      const errorText = await backendResponse.text()
      console.error('Backend error:', backendResponse.status, errorText)
      return response.status(backendResponse.status).json({
        error: 'Backend request failed',
        status: backendResponse.status,
      })
    }

    const data = await backendResponse.json()

    // Set cache headers (cache for 30 seconds, stale-while-revalidate for 60s)
    response.setHeader(
      'Cache-Control',
      's-maxage=30, stale-while-revalidate=60'
    )

    return response.status(200).json(data)
  } catch (error) {
    console.error('Proxy error:', error)
    return response.status(500).json({ error: 'Internal server error' })
  }
}
