# Scaling

## Current Compute Model

The repository uses a **zero-idle GPU baseline**:

```text
system nodes (managed) -> m7i-flex.large -> controllers and shared services
gpu nodes (dynamic)    -> g4dn.xlarge / g5.xlarge -> vLLM inference pods
```

Isolation rules:

- system nodes are labeled `workload=system`
- dynamic GPU nodes are labeled `workload=gpu`
- dynamic GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with both a matching `nodeSelector` and toleration
- the NVIDIA device plugin daemonset targets only `workload=gpu` nodes

There is **no managed GPU node group**. The cluster starts without GPU nodes,
and Karpenter launches them only when a pending pod requests `nvidia.com/gpu`.

## Default Scripted Path

`./scripts/up` installs the GPU provisioning prerequisites, but it does not
apply the inference deployment. The first GPU node should appear only during
`./scripts/verify` or a manual workload apply.

Expected shape after `./scripts/up`:

- at least two `m7i-flex.large` nodes labeled `workload=system`
- zero nodes labeled `karpenter.sh/nodepool=gpu-serving`
- one `NodePool` named `gpu-serving`
- a public inference ingress that resolves before GPU pods are launched

## Manual Scale-Out Extensions

The always-on inference edge lives in:

- `platform/inference/service.yaml`
- `platform/inference/ingress.yaml`

The deployment-only workload lives in:

- `platform/inference/vllm-openai.yaml`

The optional autoscaling manifest lives in:

- `platform/inference/hpa.yaml`

That HPA is still queue-depth-driven and still expects the supporting
observability stack. It is intentionally separate from the default scripted
workflow so the baseline stays easy to follow.

## Version Pins

- EKS control plane: `1.35`
- system node group AMI type: `AL2023_x86_64_STANDARD`
- system node group release: `1.35.2-20260304`
- Karpenter chart/CRDs: `1.9.0`
- GPU node AMI: `amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304`
- NVIDIA device plugin image: `v0.18.1`
- vLLM image: `v0.9.0`
