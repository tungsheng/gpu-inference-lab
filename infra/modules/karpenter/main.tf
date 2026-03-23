data "aws_partition" "current" {}

locals {
  node_iam_role_additional_policies = merge(
    {
      AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
    },
    var.node_iam_role_additional_policies
  )
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = var.cluster_name

  namespace       = var.namespace
  service_account = var.service_account

  create_pod_identity_association = true
  enable_spot_termination         = false

  iam_role_name            = var.iam_role_name
  iam_role_use_name_prefix = false

  node_iam_role_name                = var.node_iam_role_name
  node_iam_role_use_name_prefix     = false
  node_iam_role_attach_cni_policy   = var.node_iam_role_attach_cni_policy
  node_iam_role_additional_policies = local.node_iam_role_additional_policies

  tags = var.tags
}
