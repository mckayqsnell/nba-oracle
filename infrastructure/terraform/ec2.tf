# =============================================================================
# SSH Key Pair
# =============================================================================

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

# =============================================================================
# Elastic IP (survives instance recreation)
# =============================================================================

resource "aws_eip" "api" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip-${var.environment}"
  }
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "api" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.main.key_name
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  associate_public_ip_address = true

  # Enforce IMDSv2 for security (prevents SSRF attacks on metadata service)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Bootstrap script - installs Docker, Compose, Git, htpasswd
  # NOTE: SSL certificates are managed by the nginx-certbot container, not this script
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    project_name  = var.project_name
    htpasswd_user = var.htpasswd_user
    htpasswd_pass = var.htpasswd_pass
  })

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }

  lifecycle {
    # NOTE: Set to true after initial deployment to prevent accidental destruction
    prevent_destroy = false

    # Ignore user_data changes to prevent recreation on secret rotation
    ignore_changes = [user_data]
  }
}

# =============================================================================
# Associate Elastic IP with EC2 Instance
# =============================================================================

resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}
