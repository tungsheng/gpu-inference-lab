output "state_bucket_name" {
  description = "Bucket to put in the backend configuration of an environment."
  value       = aws_s3_bucket.state.id
}

output "backend_configuration" {
  description = "Ready-to-paste backend block for infra/env/<env>/backend_override.tf."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "dev/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
