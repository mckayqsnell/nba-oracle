#!/bin/bash
# =============================================================================
# Terraform wrapper script that pulls secrets from 1Password
# Usage: ./terraform-apply.sh [plan|apply|destroy]
# =============================================================================
set -e

# Default action
ACTION="${1:-plan}"

# For import, we need additional arguments
IMPORT_RESOURCE="${2:-}"
IMPORT_ID="${3:-}"

# Validate action
case "$ACTION" in
  init|plan|apply|destroy|output|import)
    ;;
  *)
    echo "Usage: $0 [init|plan|apply|destroy|output|import]"
    echo "       $0 import <resource> <id>"
    exit 1
    ;;
esac

# Change to terraform directory
cd "$(dirname "$0")"

# 1Password configuration (Family account, NBA-Oracle vault)
# Items needed: nba-oracle-htpasswd (Login), nba-oracle-ec2-ssh (SSH Key)
OP_ACCOUNT="my.1password.com"
OP_VAULT="NBA-Oracle"
OP_HTPASSWD_ITEM="nba-oracle-htpasswd"
OP_SSH_ITEM="nba-oracle-ec2-ssh"

echo "=== NBA Oracle Terraform Wrapper ==="
echo "Action: $ACTION"
echo ""

# Check if 1Password CLI is available
if ! command -v op &> /dev/null; then
  echo "Error: 1Password CLI (op) not found. Install it first."
  exit 1
fi

# Check if signed in to 1Password
if ! op account list &> /dev/null; then
  echo "Signing in to 1Password..."
  eval "$(op signin)"
fi

echo "Fetching secrets from 1Password..."

# Pull htpasswd credentials (from nba-oracle-htpasswd Login item)
HTPASSWD_USER=$(op item get "$OP_HTPASSWD_ITEM" --vault "$OP_VAULT" --account "$OP_ACCOUNT" --fields username 2>/dev/null) || {
  echo "Error: Could not get htpasswd username from 1Password"
  echo "Make sure Login item '$OP_HTPASSWD_ITEM' exists in vault '$OP_VAULT'"
  exit 1
}

HTPASSWD_PASS=$(op item get "$OP_HTPASSWD_ITEM" --vault "$OP_VAULT" --account "$OP_ACCOUNT" --fields password 2>/dev/null) || {
  echo "Error: Could not get htpasswd password from 1Password"
  exit 1
}

# Pull SSH public key (from nba-oracle-ec2-ssh SSH Key item)
SSH_PUBLIC_KEY=$(op item get "$OP_SSH_ITEM" --vault "$OP_VAULT" --account "$OP_ACCOUNT" --fields "public key" 2>/dev/null) || {
  echo "Error: Could not get SSH public key from 1Password"
  echo "Make sure SSH Key item '$OP_SSH_ITEM' exists in vault '$OP_VAULT'"
  exit 1
}

echo "Secrets loaded successfully."
echo ""

# Export as TF_VAR_ environment variables
export TF_VAR_htpasswd_user="$HTPASSWD_USER"
export TF_VAR_htpasswd_pass="$HTPASSWD_PASS"
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"

# Set AWS profile
export AWS_PROFILE=personal

# Run terraform with the appropriate action
case "$ACTION" in
  init)
    echo "Running: terraform init"
    terraform init
    ;;
  plan)
    echo "Running: terraform plan -var-file=prod.tfvars"
    terraform plan -var-file=prod.tfvars
    ;;
  apply)
    echo "Running: terraform apply -var-file=prod.tfvars"
    terraform apply -var-file=prod.tfvars
    ;;
  destroy)
    echo "WARNING: This will destroy all infrastructure!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      terraform destroy -var-file=prod.tfvars
    else
      echo "Aborted."
      exit 1
    fi
    ;;
  output)
    terraform output
    ;;
  import)
    if [ -z "$IMPORT_RESOURCE" ] || [ -z "$IMPORT_ID" ]; then
      echo "Usage: $0 import <resource> <id>"
      echo "Example: $0 import aws_s3_bucket.terraform_state nba-oracle-terraform-state"
      exit 1
    fi
    echo "Running: terraform import -var-file=prod.tfvars $IMPORT_RESOURCE $IMPORT_ID"
    terraform import -var-file=prod.tfvars "$IMPORT_RESOURCE" "$IMPORT_ID"
    ;;
esac

echo ""
echo "=== Done ==="
