# Dynamic GPU Serving Path

Milestone 6 delivers an end-to-end elastic GPU serving flow:

- Karpenter-managed GPU `NodePool`
- real GPU inference deployment
- load test that can trigger additional GPU node provisioning
- measurement of cold-start and scheduling milestones
- scale-down validation back to zero GPU nodes
- a fixed-vs-dynamic cost note

## Deliverables

### 1. Karpenter-managed GPU NodePool

Files:

- `platform/karpenter/nodeclass-gpu-serving.yaml`
- `platform/karpenter/nodepool-gpu-serving.yaml`

Behavior:

- launches `g4dn.xlarge` or `g5.xlarge`
- applies `workload=gpu`
- taints nodes with `gpu=true:NoSchedule`
- uses a pinned EKS AL2023 NVIDIA AMI
- consolidates empty nodes after `2m`

### 2. Real GPU inference deployment

File:

- `platform/inference/vllm-openai.yaml`

Behavior:

- runs the official vLLM OpenAI-compatible server
- serves `Qwen/Qwen2.5-0.5B-Instruct`
- requests one full GPU
- exposes a stable HTTP API through a `ClusterIP` service
- includes an HPA to request a second replica under sustained CPU load

### 3. Load test that triggers provisioning

File:

- `platform/tests/gpu-load-test.yaml`

Behavior:

- runs a `k6` job in-cluster
- repeatedly calls the vLLM `/v1/completions` endpoint
- keeps enough sustained pressure on the first replica for the HPA to ask for a
  second GPU-backed pod

### 4. Measured cold-start and scale-down timeline

Script:

- `./scripts/dev measure`

Outputs:

- a Markdown report with observed timestamps for:
  - first pod creation
  - first `NodeClaim`
  - first GPU node join
  - `nvidia.com/gpu` allocatable on the node
  - first Ready serving replica
  - HPA-driven scale-out
  - extra-node consolidation
  - full scale-down back to zero GPU nodes

## How to run it

```bash
terraform -chdir=infra/env/dev init
./scripts/dev up
./scripts/dev measure
```

Optional custom report path:

```bash
./scripts/dev measure --report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).md
```

## What success looks like

- `kubectl get nodeclaims` shows Karpenter creating a `NodeClaim` after the
  first vLLM pod is pending
- `kubectl get nodes -l karpenter.sh/nodepool=gpu-serving` grows from `0` to
  `1`
- the first vLLM pod becomes `Ready`
- under load, the HPA requests `2` replicas and Karpenter adds a second GPU
  node
- after load removal, the extra node disappears
- after deleting the inference workload, the GPU node count returns to `0`
