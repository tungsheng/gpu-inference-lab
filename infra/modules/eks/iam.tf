data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "vpc_cni_pod_identity_assume_role" {
  statement {
    sid = "PodIdentity"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  name = "gpu-inference-vpc-cni"

  assume_role_policy = data.aws_iam_policy_document.vpc_cni_pod_identity_assume_role.json
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

locals {
  cluster_access_entries = var.cluster_admin_role_arn == null ? {} : {
    cluster_admin = {
      principal_arn = var.cluster_admin_role_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  kms_key_administrators = length(var.kms_key_administrator_arns) > 0 ? var.kms_key_administrator_arns : [try(data.aws_iam_session_context.current.issuer_arn, data.aws_caller_identity.current.arn)]
}
