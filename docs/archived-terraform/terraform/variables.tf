# =============================================================================
# AWS Configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "personal"
}

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "nba-oracle"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

# =============================================================================
# Domain Configuration
# =============================================================================

variable "domain" {
  description = "API domain name (e.g., api.nbaoracle.com)"
  type        = string
}

variable "certbot_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

# =============================================================================
# EC2 Configuration
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type (t3.micro is x86-64, works with GitHub-hosted runners)"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access (from 1Password)"
  type        = string
  sensitive   = true
}

# =============================================================================
# SSH Access Control
# =============================================================================

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH (restrict to your IP for security)"
  type        = string
  default     = "0.0.0.0/0"
}

# =============================================================================
# HTTP Basic Auth (for /docs endpoint)
# =============================================================================

variable "htpasswd_user" {
  description = "Username for nginx basic auth (from 1Password)"
  type        = string
  sensitive   = true
}

variable "htpasswd_pass" {
  description = "Password for nginx basic auth (from 1Password)"
  type        = string
  sensitive   = true
}

# =============================================================================
# Docker/GHCR Configuration
# =============================================================================

variable "ghcr_image" {
  description = "GHCR image path (without tag)"
  type        = string
  default     = "ghcr.io/mckay-snell/nba-oracle-api"
}

variable "github_username" {
  description = "GitHub username for GHCR"
  type        = string
  default     = "mckay-snell"
}

# =============================================================================
# CloudWatch Alerting
# =============================================================================

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms and email notifications"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

variable "ec2_cpu_threshold" {
  description = "CPU utilization threshold for EC2 alarm (%)"
  type        = number
  default     = 80

  validation {
    condition     = var.ec2_cpu_threshold >= 1 && var.ec2_cpu_threshold <= 100
    error_message = "EC2 CPU threshold must be between 1 and 100."
  }
}
