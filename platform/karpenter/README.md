# platform/karpenter

This directory contains the Kubernetes manifests for Karpenter-managed GPU
capacity:

- `serviceaccount.yaml`
- `nodeclass-gpu-serving.yaml`
- `nodepool-gpu-serving-ondemand.yaml`
- `nodepool-gpu-serving-spot.yaml`
- `nodepool-gpu-serving-blackwell.yaml`

## Current Capacity Story

The active serving path uses two real `NodePool`s that share one GPU
`EC2NodeClass`:

- `gpu-serving-ondemand`: warm baseline and fallback serving path
- `gpu-serving-spot`: preferred burst capacity
- `gpu-serving-blackwell`: optional p6-b200.48xlarge path for full-instance
  Blackwell FP4 experiments

Both pools:

- allow `g4dn.xlarge` and `g5.xlarge`
- label nodes with `workload=gpu` and `serving=vllm`
- taint nodes with `gpu=true:NoSchedule`
- rely on the same GPU AMI and node role

The spot pool has a higher weight, so fresh burst capacity should prefer spot
when the market allows it.

The Blackwell pool is separate from the g4dn/g5 pools and labels nodes with
`gpu-arch=blackwell`. FP4 experiment serving manifests select
`p6-b200.48xlarge` directly and request 8 GPUs with `--tensor-parallel-size 8`,
which keeps p6-b200 cost accounting aligned with the full instance.

## Shared GPU NodeClass

`nodeclass-gpu-serving.yaml` pins the serving fleet to:

- AL2023 NVIDIA EKS AMI
- encrypted `120Gi` root volume
- IMDSv2-required metadata settings
- subnets and security groups discovered through cluster tags

That keeps the dynamic path reproducible instead of drifting to the latest GPU
AMI automatically.

## Warm Profile Note

The active `warm-1` workflow does **not** rely on `nodepool-gpu-warm.yaml`.
Instead, `./scripts/evaluate --profile warm-1` uses
`platform/workloads/validation/gpu-warm-placeholder.yaml` to keep one on-demand serving node
alive through the same serving path as the real workload.

The legacy warm `NodePool` manifest lives under `platform/legacy/karpenter/`
so `./scripts/down` can clean up older experiments safely without presenting it
as an active capacity definition.
