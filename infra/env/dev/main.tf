locals {
  aws_region = "us-west-2"

  azs = [
    "us-west-2a",
    "us-west-2c"
  ]
}

provider "aws" {
  region = local.aws_region
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

  azs = local.azs
}

module "eks" {
  source = "../../modules/eks"

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # Dev keeps the EKS API public for fast local iteration.
  # The production direction should be a private endpoint plus SSM/bastion/VPN access
  # and tighter public CIDR controls.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name       = module.eks.cluster_name
  iam_role_name      = "${module.eks.cluster_name}-karpenter-controller"
  node_iam_role_name = "${module.eks.cluster_name}-karpenter-node"
}
