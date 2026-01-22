# =============================================================================
# NBA Oracle - Production Environment Variables
# =============================================================================
# NOTE: Sensitive values are pulled from 1Password via terraform-apply.sh
# This file contains only non-sensitive configuration
# =============================================================================

# AWS Configuration
aws_region  = "us-west-2"
aws_profile = "personal"

# Project Configuration
project_name = "nba-oracle"
environment  = "prod"

# Domain Configuration
domain        = "api.nbaoracle.com"
certbot_email = "mckayqsnell@gmail.com"

# EC2 Configuration
instance_type    = "t3.micro"
root_volume_size = 30

# SSH Access (restrict to your IP for security, or use 0.0.0.0/0 for anywhere)
# Find your IP: curl ifconfig.me
ssh_allowed_cidr = "0.0.0.0/0"

# Docker/GHCR Configuration
ghcr_image      = "ghcr.io/mckay-snell/nba-oracle-api"
github_username = "mckay-snell"

# CloudWatch Alerting
enable_cloudwatch_alarms = true
alert_email              = "mckayqsnell@gmail.com"
ec2_cpu_threshold        = 80

# =============================================================================
# Sensitive values (passed via terraform-apply.sh from 1Password):
# - ssh_public_key
# - htpasswd_user
# - htpasswd_pass
# =============================================================================
