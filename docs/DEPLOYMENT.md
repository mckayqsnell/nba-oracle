# NBA Oracle - Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRODUCTION ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Browser                                                                    │
│      │                                                                       │
│      ▼                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  nbaoracle.com (Vercel - FREE)                                          ││
│  │  ┌─────────────────┐    ┌─────────────────────────────────────────────┐ ││
│  │  │   React SPA     │    │  Serverless Functions (BFF)                 │ ││
│  │  │   (static)      │    │  ┌─────────────────────────────────────┐    │ ││
│  │  │                 │───▶│  │ api/[...path].ts (catch-all proxy)  │    │ ││
│  │  │                 │    │  │ - Injects X-API-Key header          │    │ ││
│  │  │                 │    │  │ - Configurable per-endpoint         │    │ ││
│  │  └─────────────────┘    │  └─────────────────────────────────────┘    │ ││
│  └─────────────────────────┴───────────────────────────────────────────────┘│
│                                        │                                     │
│                                        │ HTTPS (API key in header)           │
│                                        ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  api.nbaoracle.com (EC2 t3.micro ~$8/mo)                                ││
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐    ││
│  │  │  nginx-certbot  │───▶│    FastAPI      │───▶│    ML Models     │    ││
│  │  │  (SSL + proxy)  │    │    Backend      │    │   (.joblib)      │    ││
│  │  │  :80 / :443     │    │    :8000        │    └──────────────────┘    ││
│  │  └─────────────────┘    └─────────────────┘                            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  Infrastructure: Terraform          CI/CD: GitHub Actions + 1Password        │
│  Images: GitHub Container Registry  Monitoring: CloudWatch                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Live URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | https://nbaoracle.com | React app |
| Backend API | https://api.nbaoracle.com | FastAPI backend |
| API Docs | https://api.nbaoracle.com/docs | Swagger UI (htpasswd protected) |

## Cost Estimate

| Service | Cost |
|---------|------|
| Vercel (frontend + serverless) | Free |
| EC2 t3.micro (backend) | ~$8/mo (or free tier eligible) |
| Domain (nbaoracle.com) | ~$12/yr |
| **Total** | **~$8/mo** |

---

## Frontend (Vercel)

The frontend deploys to Vercel as a static React app with serverless functions.

### Serverless Proxy (BFF Pattern)

API requests go through Vercel serverless functions to keep the API key secure:

```
Browser → /api/games/today → Vercel Function → api.nbaoracle.com/api/games/today
                                    ↓
                          Adds X-API-Key header
```

**Catch-all proxy**: `api/[...path].ts` handles all `/api/*` requests with:
- Automatic API key injection (from `API_KEY` env var)
- Per-endpoint configuration (caching, auth bypass, methods)
- Easy to extend for future endpoints

```typescript
// Example: endpoint-specific config in api/[...path].ts
const endpointConfig = {
  'games/today': { cacheDuration: 30 },
  'health': { cacheDuration: 0, skipApiKey: true },
}
```

### Environment Variables (Vercel Dashboard)

| Variable | Description |
|----------|-------------|
| `BACKEND_URL` | `https://api.nbaoracle.com` |
| `API_KEY` | API key (from 1Password `nba-oracle-frontend/prod`) |

### Custom Domain

Frontend is connected to `nbaoracle.com`:
1. DNS configured in Squarespace:
   - A record: `@` → Vercel IP
   - CNAME: `www` → `cname.vercel-dns.com`
2. SSL automatic via Vercel

---

## Backend (EC2 + GitHub Actions)

### Infrastructure (Terraform)

All infrastructure is managed via Terraform in `infrastructure/terraform/`:

```bash
# Deploy infrastructure
cd infrastructure/terraform
./terraform-apply.sh plan    # Preview changes
./terraform-apply.sh apply   # Apply changes
./terraform-apply.sh output  # Show Elastic IP, SSH command
```

**Resources created**:
- EC2 t3.micro (Amazon Linux 2023)
- Elastic IP (static, survives instance recreation)
- Security groups (SSH, HTTP, HTTPS)
- CloudWatch alarms (CPU, status checks)
- SNS topic for alerts

### EC2 Bootstrap

The `scripts/user_data.sh` script runs on first boot:
1. Installs Docker and Docker Compose
2. Creates app directory structure
3. Configures htpasswd for `/docs` protection
4. Starts Docker service

### CI/CD Pipeline

GitHub Actions automates deployment (`.github/workflows/deploy-backend.yml`):

```
Push to main → Build Image → Push to GHCR → SSH to EC2 → docker-compose up
```

**Flow**:
1. `build-and-push.yml` builds Docker image, pushes to GHCR
2. `deploy-backend.yml` SSHs to EC2, pulls image, restarts containers
3. Health checks verify deployment
4. Automatic rollback on failure

### Required Secrets

Only one GitHub secret needed:
- `OP_SERVICE_ACCOUNT_TOKEN` - 1Password service account token

All other secrets loaded dynamically from 1Password vault `NBA-Oracle`.

### Docker Compose (Production)

`docker-compose.prod.yml` runs on EC2:

| Service | Image | Purpose |
|---------|-------|---------|
| nginx | `jonasal/nginx-certbot:5-alpine` | SSL termination, reverse proxy |
| backend | `ghcr.io/*/nba-oracle-api` | FastAPI application |

**Features**:
- Automatic SSL certificate management (Let's Encrypt)
- Health checks with auto-restart
- Security hardening (no-new-privileges, cap_drop)
- Log rotation

---

## DNS Configuration

| Domain | Type | Target |
|--------|------|--------|
| `nbaoracle.com` | A | Vercel IP |
| `www.nbaoracle.com` | CNAME | `cname.vercel-dns.com` |
| `api.nbaoracle.com` | A | EC2 Elastic IP |

---

## Authentication

### Backend API Key

- Frontend sends actual API key in `X-API-Key` header (via Vercel serverless proxy)
- Backend stores SHA-256 hash in `API_KEY_HASH` env var
- Empty hash = skip verification (local dev mode)

Generate a new key/hash pair:
```python
from app.core.security import generate_api_key_and_hash
key, hash = generate_api_key_and_hash()
# Store key in 1Password: nba-oracle-frontend/prod/API_KEY
# Store hash in 1Password: nba-oracle-api/prod/API_KEY_HASH
```

### Docs Protection

`/docs` and `/redoc` are protected with htpasswd basic auth. Credentials in 1Password `nba-oracle-htpasswd`.

---

## ML Models

Models are bundled directly in the Docker image for simplicity.

### Adding a New Model

1. Train model locally or in Jupyter notebook
2. Save as `.joblib`:
   ```python
   import joblib
   joblib.dump(model, 'backend/ml/models/game_predictor.joblib')
   ```
3. Commit and push - model is included in next Docker build

### Model Size Considerations

- scikit-learn models are typically 1-50MB
- For larger models (>100MB), consider Git LFS or S3

---

## Monitoring

### Health Checks

- Backend: `GET /health` (public, no API key required)
- Nginx: Container health check every 30s
- GitHub Actions: Post-deployment health verification

### CloudWatch

- CPU utilization alarms (>80% for 5min)
- Instance status check alarms
- SNS email notifications

### Logs

```bash
# SSH to EC2 and view logs
ssh -i ~/.ssh/nba-oracle.pem ec2-user@api.nbaoracle.com

# Container logs
docker logs nba-oracle-backend-prod --follow
docker logs nba-oracle-nginx-prod --follow

# Or from project directory
docker compose -f docker-compose.prod.yml logs -f
```

---

## Rollback

GitHub Actions auto-rollback on failed health checks. Manual rollback:

```bash
# On EC2
cd ~/nba-oracle

# List backups
ls -la backup_*

# Restore from backup
BACKUP=backup_20250122_120000
cp "$BACKUP/.env.prod" .env.prod
cp "$BACKUP/docker-compose.prod.yml" docker-compose.prod.yml

# Restart
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

---

## Troubleshooting

### Container won't start
```bash
docker logs nba-oracle-backend-prod
docker compose -f docker-compose.prod.yml config
```

### SSL certificate issues
```bash
# Check certbot logs
docker logs nba-oracle-nginx-prod | grep -i cert

# Force certificate renewal
docker exec nba-oracle-nginx-prod certbot renew --force-renewal
```

### API returns 401 Unauthorized
- Check `API_KEY` in Vercel env vars
- Check `API_KEY_HASH` in backend `.env.prod`
- Verify hash matches: `echo -n "your-key" | sha256sum`

### Health check failing
```bash
# Test from EC2
docker exec nba-oracle-backend-prod python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read())"

# Test public endpoint
curl -v https://api.nbaoracle.com/health
```
