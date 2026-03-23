variable "cluster_name" {
  description = "Name of the EKS cluster Karpenter should target."
  type        = string
}

variable "iam_role_name" {
  description = "Deterministic name for the Karpenter controller IAM role."
  type        = string
}

variable "namespace" {
  description = "Namespace where the Karpenter controller service account lives."
  type        = string
  default     = "karpenter"
}

variable "service_account" {
  description = "Service account name used by the Karpenter controller."
  type        = string
  default     = "karpenter"
}

variable "node_iam_role_name" {
  description = "Deterministic name for the IAM role used by Karpenter-managed nodes."
  type        = string
}

variable "node_iam_role_attach_cni_policy" {
  description = "Whether to attach the AmazonEKS CNI policy to the Karpenter node role."
  type        = bool
  default     = false
}

variable "node_iam_role_additional_policies" {
  description = "Additional IAM policies to attach to the Karpenter node role."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to Karpenter AWS resources."
  type        = map(string)
  default     = {}
}
