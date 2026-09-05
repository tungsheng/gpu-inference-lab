# Creates the S3 bucket that holds remote Terraform state for the environments
# under infra/env/.
#
# This configuration deliberately keeps its own state local: it exists to solve
# the chicken-and-egg problem of needing a bucket before a backend can use one,
# and it manages a single bucket that is trivial to recreate or import.

terraform {
  required_version = ">= 1.5.7, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # State is the record of what exists in the account. Losing it means an
  # orphaned VPC and a manual cleanup, so make it hard to delete by accident.
  lifecycle {
    prevent_destroy = true
  }
}

# Every apply overwrites the state object. Versioning is what makes a bad
# apply recoverable rather than final.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State contains resource identifiers and, depending on the resources, secrets.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old state versions accumulate with every apply; keep enough to recover from a
# bad one without keeping them forever.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }
}
