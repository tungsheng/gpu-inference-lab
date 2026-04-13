# platform/karpenter

This directory contains the Kubernetes manifests for the repo's Karpenter-managed
GPU capacity:

- `serviceaccount.yaml`
- `nodeclass-gpu-serving.yaml`
- `nodepool-gpu-serving.yaml`
- `nodepool-gpu-warm.yaml` (legacy cleanup compatibility)

These manifests assume the current dev cluster name `gpu-inference` and the
Terraform-created Karpenter node role `gpu-inference-karpenter-node`.

The GPU `EC2NodeClass` is pinned to the Amazon EKS AL2023 NVIDIA AMI release
`amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304` so the dynamic path
stays reproducible instead of drifting to the latest GPU image automatically.

The serving `NodePool` launches `g4dn.xlarge` or `g5.xlarge` on-demand nodes,
applies `workload=gpu`, taints them with `gpu=true:NoSchedule`, and
consolidates them away after they empty.

`./scripts/evaluate --profile warm-1` now warms capacity with
`platform/tests/gpu-warm-placeholder.yaml` so it exercises the same dynamic
`gpu-serving` provisioning path used by the real inference deployment. The
legacy warm `NodePool` manifest remains here so `./scripts/down` can clean up
older experiments safely.
