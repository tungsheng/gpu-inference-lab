output "controller_role_arn" {
  value = module.karpenter.iam_role_arn
}

output "controller_role_name" {
  value = module.karpenter.iam_role_name
}

output "node_role_arn" {
  value = module.karpenter.node_iam_role_arn
}

output "node_role_name" {
  value = module.karpenter.node_iam_role_name
}
