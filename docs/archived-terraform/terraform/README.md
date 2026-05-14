# NBA Oracle - Terraform Infrastructure

This directory contains Terraform configuration for deploying the NBA Oracle backend to AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.10
- [AWS CLI](https://aws.amazon.com/cli/) configured with `personal` profile
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`)
- Signed in to 1Password: `eval "$(op signin)"`

## AWS Profile Setup

This project uses the `personal` AWS profile. Set it up:

```bash
# Configure the AWS profile (one-time setup)
aws configure --profile personal
# Enter your AWS Access Key ID, Secret, and region (us-west-2)
```

## First-Time Bootstrap

Before the first `terraform init`, create the S3 bucket for state storage:

```bash
# Create the S3 bucket
AWS_PROFILE=personal aws s3 mb s3://nba-oracle-terraform-state --region us-west-2

# Enable versioning
AWS_PROFILE=personal aws s3api put-bucket-versioning \
  --bucket nba-oracle-terraform-state \
  --versioning-configuration Status=Enabled
```

## 1Password Items Required

The following items must exist in the `NBA-Oracle` vault:

| Item Name | Type | Fields |
|-----------|------|--------|
| `nba-oracle-htpasswd` | Login | `username`, `password` |
| `nba-oracle-ec2-ssh` | SSH Key | `public key`, `private key` |

## Usage

Use the wrapper script which handles 1Password secrets:

```bash
# Initialize terraform
./terraform-apply.sh init

# Preview changes
./terraform-apply.sh plan

# Apply changes
./terraform-apply.sh apply

# View outputs (Elastic IP, SSH command, etc.)
./terraform-apply.sh output

# Destroy infrastructure (use with caution!)
./terraform-apply.sh destroy
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS (us-west-2)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────┐    ┌─────────────────────────────────┐  │
│  │  Elastic IP   │───▶│   EC2 Instance (t3.micro)       │  │
│  │  (static)     │    │   - Amazon Linux 2023           │  │
│  └───────────────┘    │   - Docker + Docker Compose     │  │
│                       │   - nginx-certbot (SSL)         │  │
│                       │   - FastAPI backend             │  │
│  ┌───────────────┐    └─────────────────────────────────┘  │
│  │ Security Group│    ┌─────────────────────────────────┐  │
│  │ - SSH (22)    │    │        S3 Bucket                │  │
│  │ - HTTP (80)   │    │   terraform state storage       │  │
│  │ - HTTPS (443) │    └─────────────────────────────────┘  │
│  └───────────────┘    ┌─────────────────────────────────┐  │
│                       │        CloudWatch               │  │
│                       │   - CPU alerts                  │  │
│                       │   - Status check alerts         │  │
│                       │   - SNS email notifications     │  │
│                       └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Outputs

After `terraform apply`, you'll get:

- `elastic_ip` - Static IP for DNS configuration
- `ssh_command` - Ready-to-use SSH command
- `dns_instructions` - What to configure in your DNS provider

## Files

| File | Purpose |
|------|---------|
| `backend.tf` | S3 remote state configuration |
| `providers.tf` | AWS provider setup |
| `variables.tf` | Input variable definitions |
| `prod.tfvars` | Production variable values (non-sensitive) |
| `ec2.tf` | EC2 instance, Elastic IP, SSH key |
| `security_groups.tf` | Firewall rules |
| `cloudwatch.tf` | Monitoring and alerts |
| `outputs.tf` | Terraform outputs |
| `scripts/user_data.sh` | EC2 bootstrap script |
| `terraform-apply.sh` | Wrapper script with 1Password integration |

## Troubleshooting

### "S3 bucket does not exist"

Run the bootstrap commands above to create the state bucket.

### 1Password authentication fails

```bash
# Sign in to 1Password
eval "$(op signin)"

# Verify access to vault
op item list --vault NBA-Oracle
```

### EC2 user_data not running

SSH to the instance and check logs:

```bash
cat /var/log/user-data.log
```
