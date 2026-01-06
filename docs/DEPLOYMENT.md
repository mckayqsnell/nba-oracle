# NBA Oracle - Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRODUCTION                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐         ┌─────────────────────────────────┐    │
│  │   Vercel    │         │      EC2 (t3.micro ~$8/mo)      │    │
│  │  (FREE)     │         │  ┌─────────┐    ┌───────────┐   │    │
│  │             │  HTTPS  │  │  nginx  │────│  FastAPI  │   │    │
│  │  React SPA  │────────▶│  │ :80/443 │    │   :8000   │   │    │
│  │  (static)   │         │  └─────────┘    └───────────┘   │    │
│  │             │         │                  │              │    │
│  └─────────────┘         │           ┌─────┴─────┐        │    │
│                          │           │ ML Models │        │    │
│                          │           │ (.joblib) │        │    │
│                          └─────────────────────────────────┘    │
│                                                                  │
│  Managed by: Terraform    Images from: GitHub Container Registry │
└─────────────────────────────────────────────────────────────────┘
```

## Cost Estimate

| Service | Cost |
| ------- | ---- |
| Vercel (frontend) | Free |
| EC2 t3.micro (backend) | ~$8/mo (or free tier eligible) |
| Domain (optional) | ~$12/yr |
| **Total** | **~$8/mo or less** |

---

## Frontend (Vercel)

The frontend is deployed as a static site to Vercel's free tier.

### Setup

1. Connect your GitHub repository to Vercel
2. Configure build settings:
   - **Framework Preset**: Vite
   - **Build Command**: `pnpm build`
   - **Output Directory**: `dist`
   - **Install Command**: `pnpm install`

3. Set environment variables:
   ```
   VITE_API_URL=https://api.your-domain.com
   ```

4. Deploy triggers automatically on push to `main`

### Custom Domain (Optional)

1. Add domain in Vercel project settings
2. Update DNS records as instructed
3. SSL is automatic

---

## Backend (EC2 + GitHub Actions)

### Prerequisites

- AWS account
- EC2 instance (t3.micro recommended)
- GitHub repository with Actions enabled
- SSH key for EC2 access

### EC2 Instance Setup

1. **Launch EC2 instance**
   - AMI: Amazon Linux 2023 or Ubuntu 22.04
   - Instance type: t3.micro (or t4g.micro for ARM)
   - Security groups: Allow ports 22, 80, 443

2. **Install Docker on EC2**
   ```bash
   # Amazon Linux 2023
   sudo dnf update -y
   sudo dnf install -y docker
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ec2-user

   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Configure GitHub Container Registry access**
   ```bash
   # Create a GitHub Personal Access Token with read:packages scope
   echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
   ```

### GitHub Actions CI/CD

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - '.github/workflows/deploy.yml'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/nba-oracle-backend

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          target: prod
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

      - name: Deploy to EC2
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /home/ec2-user/nba-oracle
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d
            docker image prune -f
```

### Required GitHub Secrets

| Secret | Description |
| ------ | ----------- |
| `EC2_HOST` | EC2 public IP or hostname |
| `EC2_USER` | SSH username (ec2-user or ubuntu) |
| `EC2_SSH_KEY` | Private SSH key for EC2 access |

### Production Environment File

On EC2, create `/home/ec2-user/nba-oracle/.env.prod`:

```bash
API_ENV=production
DEBUG=false
CORS_ORIGINS=https://your-frontend-domain.vercel.app
```

Or use 1Password CLI to generate:
```bash
task env ENV=prod
```

---

## ML Models

Models are bundled directly in the Docker image for simplicity.

### Adding a New Model

1. Train model locally or in Colab
2. Save as `.joblib`:
   ```python
   import joblib
   joblib.dump(model, 'backend/ml/models/game_predictor.joblib')
   ```
3. Commit and push - model is included in next Docker build

### Model Size Considerations

- scikit-learn models are typically 1-50MB
- For larger models (>100MB), consider:
  - Git LFS
  - S3 bucket with download on container start
  - Separate model artifact pipeline

---

## Terraform (Future)

Infrastructure-as-code configuration will live in `infrastructure/terraform/`.

Planned resources:
- EC2 instance with security groups
- Elastic IP (optional)
- IAM roles for container registry access
- CloudWatch monitoring

---

## Monitoring

### Health Checks

- Backend: `GET /health` returns `{"status": "healthy", "environment": "production"}`
- Docker Compose includes automatic health checks

### Logs

```bash
# On EC2
docker-compose -f docker-compose.prod.yml logs -f backend

# Specific service
docker logs nba-oracle-backend --follow
```

### Recommended Additions

- CloudWatch Logs agent for centralized logging
- Uptime monitoring (UptimeRobot, Pingdom free tiers)
- Error tracking (Sentry free tier)

---

## SSL/HTTPS

### Let's Encrypt with Certbot

```bash
# Install certbot
sudo dnf install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d api.your-domain.com

# Auto-renewal (already set up by certbot)
sudo certbot renew --dry-run
```

### Nginx Configuration

Place in `infrastructure/nginx/default.conf`:

```nginx
server {
    listen 80;
    server_name api.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/api.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.your-domain.com/privkey.pem;

    location / {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Rollback

If a deployment fails:

```bash
# On EC2, roll back to previous image
docker-compose -f docker-compose.prod.yml down
docker pull ghcr.io/YOUR_USERNAME/nba-oracle-backend:PREVIOUS_SHA
docker tag ghcr.io/YOUR_USERNAME/nba-oracle-backend:PREVIOUS_SHA ghcr.io/YOUR_USERNAME/nba-oracle-backend:latest
docker-compose -f docker-compose.prod.yml up -d
```

---

## Troubleshooting

### Container won't start
```bash
docker logs nba-oracle-backend
docker-compose -f docker-compose.prod.yml config  # Validate compose file
```

### Can't pull from ghcr.io
```bash
# Re-authenticate
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Health check failing
```bash
curl -v http://localhost:8000/health
docker exec nba-oracle-backend curl -v http://localhost:8000/health
```
