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
  handling is not wired to cloud-native spot interruption notices

The scripted resilience drill is implemented separately in `./scripts/evaluate`
by deleting a live spot-backed `NodeClaim`. That is useful lab evidence, but it
is not the same as Karpenter spot interruption handling.
