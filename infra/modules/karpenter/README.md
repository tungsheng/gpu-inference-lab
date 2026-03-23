# infra/modules/karpenter

This module is a thin local wrapper around the upstream
`terraform-aws-modules/eks/aws//modules/karpenter` submodule.

It provisions the AWS-side prerequisites for Karpenter in this repo:

- Controller IAM role and policy
- Pod Identity association for the `karpenter` service account
- Node IAM role and EKS access entry for Karpenter-managed nodes

The Kubernetes-side resources remain under `platform/karpenter/`.
