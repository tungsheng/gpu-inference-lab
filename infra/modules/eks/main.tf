module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "gpu-inference"
  kubernetes_version = "1.35"

  vpc_id = var.vpc_id

  subnet_ids = var.private_subnets

  enable_irsa = true

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }

    kube-proxy = {
      most_recent = true
    }

    coredns = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    systems = {
      instance_types = ["t3.micro"]

      min_size = 2
      max_size = 3

      desired_size = 2
    }
  }
}
