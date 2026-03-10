provider "aws" {
  region = "us-west-1"
}

module "vpc" {
  source = "../../modules/vpc"

  cluster_name = "gpu-inference"
  vpc_cidr     = "10.0.0.0/16"

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  azs = [
    "us-west-1a",
    "us-west-1c"
  ]
}

module "eks" {
  source = "../../modules/eks"

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  endpoint_public_access       = true          #length(var.eks_public_access_cidrs) > 0
  endpoint_public_access_cidrs = ["0.0.0.0/0"] #var.eks_public_access_cidrs

  enable_cluster_creator_admin_permissions = true
}
