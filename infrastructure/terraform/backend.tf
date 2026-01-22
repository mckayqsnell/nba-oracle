# Remote state storage in S3 with native S3 locking
# No DynamoDB required - uses S3 Conditional Writes (Terraform 1.10+)
#
# Bootstrap: Before first terraform init, create the S3 bucket manually:
#   AWS_PROFILE=personal aws s3 mb s3://nba-oracle-terraform-state --region us-west-2
#   AWS_PROFILE=personal aws s3api put-bucket-versioning \
#     --bucket nba-oracle-terraform-state --versioning-configuration Status=Enabled
#
terraform {
  backend "s3" {
    bucket       = "nba-oracle-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-west-2"
    profile      = "personal"
    encrypt      = true
    use_lockfile = true # Uses S3 native locking (no DynamoDB needed)
  }
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "nba-oracle-terraform-state"

  # Prevent accidental deletion of state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "nba-oracle-terraform-state"
    Purpose = "Terraform state storage for NBA Oracle"
  }
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
