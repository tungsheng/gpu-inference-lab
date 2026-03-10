module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "gpu-inference"
  kubernetes_version = "1.35"

  vpc_id = var.vpc_id

  subnet_ids = var.private_subnets

  endpoint_private_access      = var.endpoint_private_access
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  access_entries                           = local.cluster_access_entries
  kms_key_administrators                   = local.kms_key_administrators

  addons = {
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }

    vpc-cni = {
      before_compute = true
      most_recent    = true
      pod_identity_association = [{
        role_arn        = aws_iam_role.vpc_cni.arn
        service_account = "aws-node"
      }]
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
      instance_types             = ["t3.micro"]
      iam_role_attach_cni_policy = false

      min_size = 6
      max_size = 10

      desired_size = 8
    }
  }
}
