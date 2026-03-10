variable "eks_public_access_cidrs" {
  description = "Trusted CIDR blocks allowed to reach the EKS public API endpoint. Leave empty to keep the endpoint private-only."
  type        = list(string)
  default     = []
}
