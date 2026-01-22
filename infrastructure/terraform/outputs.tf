# =============================================================================
# EC2 Instance Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.api.id
}

output "elastic_ip" {
  description = "Elastic IP address (use for DNS A record)"
  value       = aws_eip.api.public_ip
}

output "private_ip" {
  description = "Private IP within VPC"
  value       = aws_instance.api.private_ip
}

# =============================================================================
# Security Group Output
# =============================================================================

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instance"
  value       = aws_security_group.ec2.id
}

# =============================================================================
# AMI Info (useful for debugging)
# =============================================================================

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.amazon_linux.id
}

output "ami_name" {
  description = "AMI name (shows OS version)"
  value       = data.aws_ami.amazon_linux.name
}

# =============================================================================
# SSH Command Helper
# =============================================================================

output "ssh_command" {
  description = "SSH command to connect (uses 1Password SSH agent)"
  value       = "ssh nba-oracle  # After updating ~/.ssh/config with IP: ${aws_eip.api.public_ip}"
}

# =============================================================================
# DNS Instructions
# =============================================================================

output "dns_instructions" {
  description = "DNS configuration instructions"
  value       = <<-EOT

    Configure DNS A record:
      ${var.domain} → ${aws_eip.api.public_ip}

    After DNS propagates, SSL certificate will be auto-requested.
    Monitor: ssh nba-oracle 'tail -f /var/log/certbot-setup.log'
  EOT
}

# =============================================================================
# CloudWatch Outputs
# =============================================================================

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = var.enable_cloudwatch_alarms ? aws_sns_topic.alerts[0].arn : null
}
