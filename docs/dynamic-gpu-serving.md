# Dynamic GPU Serving Path

Milestone 6 still centers on the same elastic GPU serving idea:

- Karpenter-managed GPU `NodePool`
- real GPU inference deployment
- public inference edge
- scale-down validation back to zero GPU nodes

The difference is that the default scripted path now focuses on the smallest
useful proof of that behavior.

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

Files:

- `platform/inference/vllm-openai.yaml`
- `platform/inference/service.yaml`
- `platform/inference/ingress.yaml`

Behavior:

- runs the official vLLM OpenAI-compatible server
- serves `Qwen/Qwen2.5-0.5B-Instruct`
- requests one full GPU
- exposes a public `/v1/completions` path through the ALB ingress

### 3. Default automated verification

Script:

- `./scripts/verify`

Outputs:

- a short timing summary for:
  - first GPU node observed
  - first Ready deployment
  - first successful public response
  - return to zero GPU nodes after cleanup

### 4. Optional autoscaling assets

Files:

- `platform/inference/hpa.yaml`
- `platform/tests/gpu-load-test.yaml`
- `platform/observability/`

These are intentionally outside the default lifecycle so the baseline stays
small and easy to follow.

## How To Run It

```bash
./scripts/up
./scripts/verify
```

## What Success Looks Like

- `kubectl get nodeclaims` shows Karpenter reacting after the vLLM pod is pending
- `kubectl get nodes -l karpenter.sh/nodepool=gpu-serving` grows from `0` to `1`
- the first vLLM pod becomes `Ready`
- the public inference edge returns a successful completion
- after deleting the workload, the GPU node count returns to `0`
