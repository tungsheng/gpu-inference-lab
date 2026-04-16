# infra/modules/karpenter

This module is a thin wrapper around the upstream
`terraform-aws-modules/eks/aws//modules/karpenter` submodule.

It provisions the AWS-side prerequisites that let Karpenter manage GPU nodes in
this repo.

## What It Creates

- controller IAM role and policy
- Pod Identity association for the `karpenter` service account
- node IAM role for Karpenter-managed instances
- EKS access entry for the Karpenter node role
- Amazon SSM managed policy on launched nodes

## Repo-Specific Notes

- Kubernetes-side manifests remain under `platform/karpenter/`
- the current module keeps `enable_spot_termination = false`, so interruption
  handling is not yet part of the implemented platform story

This is a good example of the repo's current maturity: mixed capacity is
implemented, but deeper spot resilience work is still on the roadmap.
