variable "aws_region" {
  description = "Region the state bucket lives in. Match the environment it serves."
  type        = string
  default     = "us-west-2"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state, for example gpu-inference-lab-tfstate-<account-id>."
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "How long superseded state versions are kept before expiry."
  type        = number
  default     = 90
}
