module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "gpu-inference"
  kubernetes_version = "1.35"

  vpc_id = var.vpc_id

  subnet_ids = var.private_subnets

  node_security_group_tags = {
    "karpenter.sh/discovery" = "gpu-inference"
  }

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
    system = {
      instance_types             = ["m7i-flex.large"]
      ami_type                   = "AL2023_x86_64_STANDARD"
      ami_release_version        = "1.35.2-20260304"
      iam_role_attach_cni_policy = false

      labels = {
        workload                  = "system"
        "karpenter.sh/controller" = "true"
      }

      desired_size = 2
      min_size     = 2
      max_size     = 3
    }
  }
}
