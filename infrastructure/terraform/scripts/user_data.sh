#!/bin/bash
# EC2 User Data Script - Runs on first boot
# Installs: Docker, Docker Compose v2, Git, htpasswd tools
# NOTE: SSL certificates are managed by the nginx-certbot Docker container, not this script
set -e

# Variables passed from Terraform (templatefile)
PROJECT_NAME="${project_name}"
HTPASSWD_USER="${htpasswd_user}"
HTPASSWD_PASS="${htpasswd_pass}"

# Log everything to file for debugging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting user data script at $(date) ==="

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install Docker
echo "Installing Docker..."
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose (as Docker CLI plugin)
# Check https://github.com/docker/compose/releases for updates
COMPOSE_VERSION="v2.32.4"
echo "Installing Docker Compose $${COMPOSE_VERSION}..."
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version

# Install Git
echo "Installing Git..."
dnf install -y git

# Install httpd-tools (provides htpasswd for nginx basic auth)
echo "Installing httpd-tools..."
dnf install -y httpd-tools

# Create nginx config directory and htpasswd file on HOST
# This file is mounted into the nginx container via docker-compose
echo "Creating htpasswd file for $${PROJECT_NAME}..."
mkdir -p /etc/nginx
htpasswd -bc /etc/nginx/.htpasswd-$${PROJECT_NAME} "$${HTPASSWD_USER}" "$${HTPASSWD_PASS}"
chmod 644 /etc/nginx/.htpasswd-$${PROJECT_NAME}

# Create application directory
echo "Creating application directory..."
mkdir -p /home/ec2-user/$${PROJECT_NAME}
chown -R ec2-user:ec2-user /home/ec2-user/$${PROJECT_NAME}

echo "=== User data script completed at $(date) ==="
echo ""
echo "SETUP COMPLETE! Next steps:"
echo "1. Clone the repository: git clone <repo-url> /home/ec2-user/$${PROJECT_NAME}"
echo "2. Login to GHCR: echo \$GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin"
echo "3. Deploy: docker compose -f docker-compose.prod.yml up -d"
echo "4. SSL certificates will be automatically obtained by the nginx-certbot container"
