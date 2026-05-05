# NBA Oracle

ML-powered NBA game predictions with live score tracking.

**Live:** [nbaoracle.com](https://nbaoracle.com)

## Tech Stack

- **Frontend**: React + TypeScript + Vite + Tailwind CSS (Vercel)
- **Backend**: FastAPI + Python 3.13 (Mac Mini M4 via Cloudflare Tunnel)
- **ML**: scikit-learn + Jupyter notebooks
- **Infrastructure**: Docker Compose + Watchtower + GitHub Actions
- **Secrets**: 1Password

## Features

- Real-time NBA game predictions
- Adaptive live score updates (5s during games, less frequent otherwise)
- Machine learning models trained on historical data
- Clean, responsive dark-themed UI
- Secure API with key authentication

## Quick Start

```bash
# Install task runner (if not installed)
brew install go-task

# First time setup (requires 1Password CLI)
task setup

# Start development environment
task dev
```

## Development

| Command | Description |
| ------- | ----------- |
| `task dev` | Start development environment |
| `task clean` | Stop and clean up |
| `task logs` | View container logs |
| `task env` | Sync env vars from 1Password |

## Architecture

```text
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  nbaoracle.com   │     │ api.nbaoracle.com│     │  Mac Mini M4     │
│     (Vercel)     │────▶│ Cloudflare Tunnel│────▶│  FastAPI + ML    │
│  React + BFF     │     │   (TLS at edge)  │     │  (Docker)        │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

- **Frontend** deploys to Vercel with serverless functions as API proxy
- **Backend** runs on a self-hosted Mac Mini; Watchtower auto-pulls new images from GHCR
- **Public exposure** via Cloudflare Tunnel (zero open ports on the host; TLS terminated at Cloudflare's edge)

See [docs/MIGRATION.md](docs/MIGRATION.md) for the deployment architecture and runbook.
