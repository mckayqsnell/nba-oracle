# Archived: pre-Cloudflare-Tunnel EC2 infrastructure

Archived 2026-05-14. These files describe the legacy AWS EC2 + nginx + Let's Encrypt deployment that ran the backend before the migration to a self-hosted Mac Mini behind a Cloudflare Tunnel.

**None of this is active.** The EC2 instance, Elastic IP, security group, CloudWatch alarms, and Terraform state bucket were destroyed during the migration. The current deployment is documented in [../MIGRATION.md](../MIGRATION.md).

## What's here

| Path | What it was |
|---|---|
| `terraform/` | Terraform module that provisioned the EC2 stack (instance, EIP, SG, CloudWatch alarms, SNS topic, S3 state bucket). |
| `tasks-infra.yml` | The old `tasks/infra.yml` — Taskfile wrapper around `terraform apply`/`destroy` that pulled sensitive vars from 1Password. |
| `deploy-backend.yml` | The old `.github/workflows/deploy-backend.yml` — SSH-based GHA deploy that pushed images to the EC2 host. |
| `load-secrets/` | The old composite action used by `deploy-backend.yml` to pull deploy-time secrets from 1Password. |
| `nginx/` | The old `infrastructure/nginx/user_conf.d/` — nginx-certbot config (TLS termination, Basic Auth for `/docs`, reverse proxy to the backend container). |

## Why archive instead of delete

Useful as a reference if I ever rebuild a similar EC2-fronted stack, and the history is preserved in git either way. Nothing here gets executed.
