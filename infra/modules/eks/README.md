# infra/modules/eks

This module wraps `terraform-aws-modules/eks/aws` for the repo's current EKS
contract.

## What It Owns

- EKS control plane creation
- managed system node group configuration
- cluster endpoint settings
- core add-ons such as Pod Identity Agent, VPC CNI, CoreDNS, and kube-proxy
- IAM and access-entry wiring needed by the repo

## Current Shape

The module is intentionally simple:

- Kubernetes version `1.35`
- one managed system node group on `m7i-flex.large`
- system nodes labeled `workload=system`
- no managed GPU node group
- node security group tagged for Karpenter discovery

GPU capacity is deliberately handled outside this module by Karpenter.

## Repo-Specific Notes

- the caller decides whether the EKS endpoint is public or private
- the active dev environment keeps public endpoint access enabled for faster
  iteration
- Karpenter, the public inference edge, and observability are installed later by
  the lifecycle scripts rather than by this Terraform module
