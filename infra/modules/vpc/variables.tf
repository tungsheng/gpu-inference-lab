variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name used to derive VPC and subnet tags."
  type        = string
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) == length(var.azs)
    error_message = "public_subnets must contain one CIDR block per availability zone."
  }
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) == length(var.azs)
    error_message = "private_subnets must contain one CIDR block per availability zone."
  }
}

variable "azs" {
  description = "Availability zones used for the public and private subnets."
  type        = list(string)
}
