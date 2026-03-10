variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "endpoint_private_access" {
  description = "Enable the private EKS API endpoint."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public EKS API endpoint."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant cluster admin access to the identity running Terraform. Prefer a dedicated admin role for longer-lived access."
  type        = bool
  default     = false
}

variable "cluster_admin_role_arn" {
  description = "IAM role ARN to grant AmazonEKSClusterAdminPolicy access to."
  type        = string
  default     = null

  validation {
    condition     = var.cluster_admin_role_arn == null || length(regexall(":role/", var.cluster_admin_role_arn)) > 0
    error_message = "cluster_admin_role_arn must be an IAM role ARN."
  }
}

variable "kms_key_administrator_arns" {
  description = "IAM role or root ARNs to administer the EKS KMS key. Defaults to the account root principal to avoid binding the key to the Terraform caller."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.kms_key_administrator_arns :
      length(regexall(":role/|:root$", arn)) > 0
    ])
    error_message = "kms_key_administrator_arns must contain only IAM role ARNs or the account root ARN."
  }
}
