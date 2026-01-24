# NBA Oracle

ML-powered NBA game predictions with live score tracking.

**Live:** [nbaoracle.com](https://nbaoracle.com)

## Tech Stack

- **Frontend**: React + TypeScript + Vite + Tailwind CSS (Vercel)
- **Backend**: FastAPI + Python 3.13 (EC2)
- **ML**: scikit-learn + Jupyter notebooks
- **Infrastructure**: Terraform + Docker + GitHub Actions
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

```
┌──────────────────┐     ┌──────────────────┐
│  nbaoracle.com   │     │ api.nbaoracle.com│
│     (Vercel)     │────▶│      (EC2)       │
│  React + BFF     │     │  FastAPI + ML    │
└──────────────────┘     └──────────────────┘
```

- **Frontend** deploys to Vercel with serverless functions as API proxy
- **Backend** deploys to EC2 via GitHub Actions
- **Infrastructure** managed with Terraform

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for full deployment guide.
