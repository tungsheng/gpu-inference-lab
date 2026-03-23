data "aws_region" "current" {}

output "aws_region" {
  value = data.aws_region.current.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "karpenter_controller_role_arn" {
  value = module.karpenter.controller_role_arn
}

output "karpenter_controller_role_name" {
  value = module.karpenter.controller_role_name
}

output "karpenter_node_role_arn" {
  value = module.karpenter.node_role_arn
}

output "karpenter_node_role_name" {
  value = module.karpenter.node_role_name
}
