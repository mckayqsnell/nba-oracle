# NBA Oracle: AWS EC2 → Mac Mini Migration Guide

This is the finetuned migration plan for **your** nba-oracle repo. Every step is grounded in the files you actually have today (compose, Terraform, GHA workflows, 1Password items).

> **Estimated downtime:** ~5–10 minutes during the DNS/tunnel cutover. Do this when you don't mind the API being briefly unavailable.

---

## Phase 0 — What's changing (overview)

| Layer | Before (EC2) | After (Mac Mini) |
|------|------|------|
| Host | EC2 t3.micro (Terraform-managed) | Mac Mini M4 (Tailscale-only SSH) |
| TLS termination | `nginx-certbot` container + Let's Encrypt | Cloudflare Tunnel (no nginx, no certs) |
| Public exposure | Elastic IP + ports 80/443 | Cloudflare Tunnel (zero open ports) |
| `/docs` auth | nginx htpasswd | Cloudflare Access (Zero Trust, free) |
| DNS for `nbaoracle.com` | Squarespace | Cloudflare nameservers |
| Deploy method | GHA → SSH → docker-compose | GHA push image → Watchtower auto-pulls |
| Secrets to server | GHA loads from 1Password → SCP | `task secrets:push` from MacBook |

**What stays the same:** Vercel still hosts the frontend. The `[...path].ts` BFF proxy still injects `X-API-Key`. Only `BACKEND_URL` in Vercel will need to keep pointing at `https://api.nbaoracle.com` (which now resolves through Cloudflare Tunnel instead of the EC2 Elastic IP).

---

## Phase 1 — Prep work on Mac Mini (do first)

You're already mid-way through your `mac-mini-server-guide.md`. Before you do anything destructive on AWS:

1. **Confirm the mini is ready:**
   ```bash
   ssh mini 'docker info | grep "Server Version"'
   ssh mini 'docker compose version'
   ssh mini 'gh auth status'
   ```
   All three should succeed.

2. **Make sure GHCR is logged in on the mini** (Watchtower will need this to pull the private image, though `nba-oracle-api` is currently set to public — verify):
   ```bash
   # Check current visibility
   gh api /user/packages/container/nba-oracle-api --jq '.visibility'
   ```
   - If `public` → Watchtower works without auth. Skip the next step.
   - If `private` → on the mini:
     ```bash
     ssh mini
     echo $GITHUB_TOKEN | docker login ghcr.io -u mckayqsnell --password-stdin
     ```
     Use a PAT with `read:packages` scope, store it in 1Password.

3. **Create the project directory on the mini:**
   ```bash
   ssh mini 'mkdir -p ~/projects/nba-oracle && chmod 700 ~/projects/nba-oracle'
   ```

---

## Phase 2 — Cloudflare account + tunnel setup

### 2.1 — Create Cloudflare account

1. Sign up at https://cloudflare.com (free tier).
2. **No credit card required** for what you need. Free tier covers:
   - Unlimited Cloudflare Tunnels (account limit is 1,000)
   - Cloudflare Access for up to 50 users (you're a team of 1)
   - DNS hosting for unlimited domains
   - Free SSL certs
3. Enable 2FA immediately (Settings → Authentication).

### 2.2 — Move `nbaoracle.com` DNS to Cloudflare

You have two paths. **Use Path A** — it's the official "Full Setup" Cloudflare recommends for tunnels and it's much simpler than the partial CNAME alternative.

**Path A — Move nameservers to Cloudflare (recommended):**

1. Cloudflare dashboard → **Add a Site** → enter `nbaoracle.com` → choose **Free** plan.
2. Cloudflare scans your existing DNS. **Verify the scan caught your Vercel records** (the A record for the apex and CNAME for `www`). If anything's missing, add it manually now.
3. Cloudflare gives you two nameservers (something like `xxx.ns.cloudflare.com`).
4. Squarespace → **Domains** → `nbaoracle.com` → **DNS Settings** → change to custom nameservers → paste Cloudflare's two nameservers.
5. Wait for propagation. Cloudflare will email you when active. Usually 15 min – 24 hrs; in practice, ~1 hour.
6. Cloudflare dashboard shows the domain as **Active**. Confirm Vercel still resolves (`https://nbaoracle.com` should still work).

**About `mckaysnell.com`:** You don't need to move it. Cloudflare manages domains independently. You can leave your portfolio on Squarespace and only move `nbaoracle.com`. (Whether to consolidate later is a separate decision — see the Cloudflare Tunnel Playbook.)

### 2.3 — Create the tunnel

1. Cloudflare dashboard → **Zero Trust** (left sidebar) → on first visit it'll ask you to pick a team name (this becomes your `<team>.cloudflareaccess.com` URL — pick something like `mckaysnell`).
2. **Networks** → **Tunnels** → **Create a tunnel** → **Cloudflared** connector → name it `mac-mini`.
3. Cloudflare displays a token. **Copy it now** and save it to 1Password as a new field on `nba-oracle-api` → prod section → field name `TUNNEL_TOKEN`.
4. Skip the install commands Cloudflare suggests — your Docker Compose handles cloudflared.
5. **Public Hostname** tab → add a route:

   | Field | Value |
   |---|---|
   | Subdomain | `api` |
   | Domain | `nbaoracle.com` |
   | Path | (leave blank) |
   | Service Type | `HTTP` |
   | URL | `backend:8000` |

   This tells the tunnel: traffic to `api.nbaoracle.com` should proxy to the `backend` container on port 8000 (Docker Compose service name resolution).

### 2.4 — (Optional but recommended) Protect `/docs` with Cloudflare Access

This replaces your htpasswd basic auth with email OTP — better UX, zero secrets to manage.

1. Zero Trust → **Access** → **Applications** → **Add an application** → **Self-hosted**.
2. Name: `nba-oracle-docs`.
3. Application domain: `api.nbaoracle.com`, path `/docs`.
4. Add another row for path `/redoc` and `/openapi.json` (same domain).
5. Identity providers: enable **One-time PIN** (free, no setup).
6. **Add a policy** → name `Allow me`, action `Allow`, include rule: `Emails` → your email.

Now hitting `/docs` will email you a one-time PIN. Once you authenticate, you get a session cookie for ~24h.

---

## Phase 3 — Update the nba-oracle repo

These are the file changes. You can do them by hand or use the Claude Code prompt in `claude-code-prompts.md`.

### 3.1 — Replace `docker-compose.prod.yml`

The new version: no nginx, no SSL, no exposed ports. Cloudflared and backend live on the same private bridge network.

```yaml
# docker-compose.prod.yml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: nba-oracle-cloudflared
    command: tunnel --no-autoupdate run
    env_file:
      - .env.prod   # TUNNEL_TOKEN comes from here
    restart: unless-stopped
    networks:
      - app
    depends_on:
      backend:
        condition: service_healthy
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  backend:
    image: ghcr.io/mckayqsnell/nba-oracle-api:latest
    container_name: nba-oracle-backend
    env_file:
      - .env.prod
    environment:
      - API_ENV=production
      - DEBUG=false
    restart: unless-stopped
    networks:
      - app
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

networks:
  app:
    driver: bridge
```

Key differences from your current file:
- ✂️ Removed: `nginx` service, `nginx_letsencrypt` volume, port mappings, `IMAGE_TAG` interpolation
- ➕ Added: `cloudflared` service, `watchtower.enable=true` labels (since you're using `WATCHTOWER_LABEL_ENABLE=false` in the global Watchtower install per your guide, you can remove the labels — but if you set `WATCHTOWER_LABEL_ENABLE=true` later, they're already there)
- 🔄 Changed: image is hardcoded to `:latest` (Watchtower polls this tag)

### 3.2 — Delete EC2/nginx infrastructure files

After Phase 5 (teardown), delete from your repo:
- `infrastructure/nginx/` (entire dir — no more nginx)
- `.github/workflows/deploy-backend.yml` (no more SSH deploy)
- `.github/actions/load-secrets/` (was used by deploy-backend)
- `tasks/infra.yml` ssh and build:prod tasks (most of `infra.yml` was EC2-focused — the s3 state stuff still applies if you keep terraform around for archeology, otherwise delete the whole file)

Keep:
- `.github/workflows/build-and-push.yml` — but update it (see §3.4)
- `.github/workflows/cleanup-images.yml` — still useful
- `infrastructure/terraform/` — keep until Phase 5, then optionally archive

### 3.3 — Add `tasks/secrets.yml` to your Taskfile

Drop the `secrets.yml` file (delivered alongside this guide) into `tasks/` and add the include to your main `Taskfile.yml`:

```yaml
# Taskfile.yml
includes:
  env:
    taskfile: ./tasks/env.yml
    dir: .
  helpers:
    taskfile: ./tasks/helpers.yml
    dir: .
  secrets:                         # ← add this
    taskfile: ./tasks/secrets.yml  # ← add this
    dir: .                         # ← add this
  # infra: keep or remove based on §3.2 decision
```

Then test (without pushing yet):
```bash
task secrets:push:dry-run
```

### 3.4 — Update `.github/workflows/build-and-push.yml`

Currently it's `workflow_call` only and runs on `ubuntu-latest` (x86). For the new architecture you want:
- Push trigger on `main` (no more chained workflow)
- ARM64 native runner (Mac Mini M4 is ARM64)
- Tag `:latest` for Watchtower to pull

There's a Claude Code prompt in `claude-code-prompts.md` that does this with Context7 and proper error handling.

### 3.5 — Add 1Password fields

In your existing `nba-oracle-api` Secure Note, **prod section**:
- ✅ Already there: `API_KEY_HASH`, `BALLDONTLIE_API_KEY`, `CORS_ORIGINS`
- ➕ **Add**: `TUNNEL_TOKEN` (from §2.3)
- ❌ **Remove**: `CERTBOT_EMAIL` (no more Let's Encrypt)

Then on your MacBook:
```bash
cd ~/projects/nba-oracle
task env:generate ENV=prod
cat .env.prod  # sanity check — should include TUNNEL_TOKEN
```

---

## Phase 4 — Cutover

This is the only step with downtime.

1. **On the Mac Mini**, clone the repo (if not already):
   ```bash
   ssh mini
   cd ~/projects/nba-oracle
   git clone https://github.com/mckayqsnell/nba-oracle.git .  # or pull latest
   ```

2. **From your MacBook** (the secrets push):
   ```bash
   cd ~/projects/nba-oracle  # local clone with the new compose file
   task secrets:push
   ```
   This generates `.env.prod` from 1Password (now including `TUNNEL_TOKEN`), copies it to the mini, and starts the new compose stack.

   First-time run: it'll fail the `_verify` step because Cloudflare DNS doesn't yet route to the new tunnel. That's fine — keep going.

3. **Verify the tunnel is up locally on the mini:**
   ```bash
   ssh mini
   cd ~/projects/nba-oracle
   docker compose -f docker-compose.prod.yml ps
   docker compose -f docker-compose.prod.yml logs cloudflared --tail=20
   # Look for: "Registered tunnel connection"
   ```

4. **In Cloudflare dashboard:** Zero Trust → Networks → Tunnels → `mac-mini` should show **HEALTHY** with active connectors.

5. **Cutover DNS:** the public hostname rule you set in §2.3 already does this. Once the tunnel is healthy, `https://api.nbaoracle.com` resolves via Cloudflare → tunnel → mini. Test:
   ```bash
   # From any machine:
   curl -v https://api.nbaoracle.com/health
   # Expect: 200 with {"status":"healthy",...}
   ```

6. **Update Vercel env var (if needed):** `BACKEND_URL` should still be `https://api.nbaoracle.com`. No change needed — only the IP behind it changed.

---

## Phase 5 — Tear down EC2

Only do this once `https://api.nbaoracle.com/health` reliably returns 200 through Cloudflare and you've watched it for at least an hour.

### 5.1 — Run terraform destroy

```bash
cd ~/projects/nba-oracle/infrastructure/terraform
./terraform-apply.sh destroy
```

Type `yes` at the prompt. This destroys:
- EC2 instance `nba-oracle-prod`
- Elastic IP
- Security group
- Key pair
- CloudWatch alarms (CPU, status check)
- SNS topic + email subscription
- Local terraform state references

### 5.2 — Manually delete the S3 state bucket (if you want full cleanup)

The state bucket has `prevent_destroy = true` lifecycle rule, so terraform won't delete it. Two options:

**Option A — keep it as an archive** (basically free, ~few cents/year):
- Do nothing. You can always reference what was there.

**Option B — delete it** (full cleanup):
```bash
AWS_PROFILE=personal aws s3 rm s3://nba-oracle-terraform-state --recursive
AWS_PROFILE=personal aws s3 rb s3://nba-oracle-terraform-state
```
Note: deleting the bucket means losing the audit trail of all your past terraform changes. For a personal project, fine.

### 5.3 — Cancel CloudWatch alarms email subscription

If you confirmed your SNS email subscription, AWS may keep sending you "you've been unsubscribed" notifications. Just ignore — the SNS topic is gone.

### 5.4 — Verify zero AWS spend going forward

```bash
AWS_PROFILE=personal aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,State.Name]' --output table
AWS_PROFILE=personal aws ec2 describe-addresses --output table
```

Both should be empty (or terminated-only). Check the AWS Billing dashboard in 24 hrs to confirm no unexpected charges.

### 5.5 — Clean up 1Password items

Move these to an "Archive" vault or delete:
- `nba-oracle-htpasswd` (no more nginx basic auth)
- `nba-oracle-ec2-ssh` (no more EC2 SSH key)
- `nba-oracle-ec2` (no more EC2 host)

Keep:
- `nba-oracle-api` — still your main project secrets store

### 5.6 — GitHub repo secrets cleanup

Repo Settings → Secrets and variables → Actions → delete:
- `OP_SERVICE_ACCOUNT_TOKEN` (was used by deploy-backend.yml's load-secrets action)

Anything else specific to the EC2 deploy. Keep the default `GITHUB_TOKEN` — that's automatic.

---

## Phase 6 — Verify everything

**Functional smoke tests:**
```bash
# Public API
curl https://api.nbaoracle.com/health
curl https://api.nbaoracle.com/api/games/today | jq '.games | length'

# Frontend (Vercel proxy → Cloudflare Tunnel → mini)
curl https://nbaoracle.com/api/games/today | jq '.games | length'

# Docs (should prompt for Cloudflare Access OTP)
open https://api.nbaoracle.com/docs
```

**Operational smoke tests:**
```bash
# Watchtower picks up new image (push something trivial to main, wait ~5min)
ssh mini 'docker logs watchtower --tail=20'

# Secrets rotation works
# Edit a non-critical secret in 1Password, then:
task secrets:push
# Verify the change took effect (e.g., a new BALLDONTLIE_API_KEY would still let the API work)
```

**iOS Shortcut for phone trigger:**

1. iPhone → **Shortcuts** app → **+** → name it "Push NBA Oracle Secrets".
2. Add action **"Run script over SSH"** (search "ssh"). Note: this requires your iPhone to be on the same Tailscale network as your MacBook.
3. Configure:
   - Host: your MacBook's Tailscale name (e.g., `macbook.tail-scale.ts.net`)
   - User: your macOS username
   - Authentication: **SSH Key** → generate one in Shortcuts and add the public key to `~/.ssh/authorized_keys` on your MacBook
   - Script:
     ```bash
     cd ~/projects/nba-oracle && /opt/homebrew/bin/task secrets:push
     ```
4. Tap-test from the phone. Add to your Home Screen for one-tap access.
5. Pair with a monthly Reminder ("Rotate NBA Oracle secrets") set to repeat → Monthly. Done.

---

## Done

After this you have:
- Zero monthly AWS spend (down from ~$8/mo)
- One-command secret rotation from your MacBook
- One-tap secret rotation from your phone
- Auto-deploy via Watchtower on every push to main
- Better /docs auth (Cloudflare Access OTP vs htpasswd)
- A pattern you can copy for every future project: vault → tunnel → mini.
