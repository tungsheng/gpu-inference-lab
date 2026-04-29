# Inference

The repo serves a real GPU-backed model through vLLM and exposes an
OpenAI-compatible `/v1` path through an AWS Application Load Balancer.

## Assets

Inference manifests live in `platform/inference/`:

- `vllm-openai.yaml`: deployment-only vLLM workload
- `service.yaml`: stable in-cluster `ClusterIP` service
- `ingress.yaml`: public ALB-backed `/v1` path
- `hpa.yaml`: running-request HPA policy
- `hpa-active-pressure.yaml`: active-pressure HPA policy

The scripts use these files deliberately:

- `./scripts/up` applies only the service and ingress
- `./scripts/verify` applies only the deployment
- `./scripts/evaluate` applies the deployment plus one selected HPA policy, or
  runs compare/sweep workflows

That split keeps the public edge online while GPU serving capacity stays at
zero until a validation or evaluation run starts.

## Serving Stack

- image: `vllm/vllm-openai:v0.9.0`
- model: `Qwen/Qwen2.5-0.5B-Instruct`
- served model name: `qwen2.5-0.5b`
- health path: `/health`
- container port: `8000`
- GPU request and limit: `nvidia.com/gpu: 1`

The workload selects `workload=gpu`, tolerates `gpu=true:NoSchedule`, and cannot
land on the managed system node group. Pending GPU demand is what lets
Karpenter prove dynamic serving capacity.

## Autoscaling Policies

Both HPA policies target the same `vllm-openai` deployment with `minReplicas: 1`
and `maxReplicas: 2`.

| Policy | Manifest | Metric | Default target |
| --- | --- | --- | --- |
| `running` | `hpa.yaml` | `vllm_requests_running` | `128` |
| `active-pressure` | `hpa-active-pressure.yaml` | `vllm_requests_active = waiting + running` | `4` |

Use `./scripts/evaluate --policy ...` for normal validation. If applying
manifests manually, apply only one HPA policy at a time because both manifests
use the same HPA name.

## Warm Profile

`./scripts/evaluate --profile warm-1` applies
`platform/workloads/validation/gpu-warm-placeholder.yaml` before starting the
real vLLM deployment. The placeholder keeps one on-demand serving node alive
without requesting the GPU resource, which lets the run compare lower
first-response latency against higher idle cost.

## Manual Checks

Watch scheduling and autoscaling:

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,karpenter.sh/nodepool,karpenter.sh/capacity-type -w
```

Test the public edge after `./scripts/up` and a Ready serving pod:

```bash
EDGE_HOST=$(kubectl get ingress vllm-openai-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${EDGE_HOST}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-0.5b","prompt":"Say hello from the public edge.","max_tokens":32,"temperature":0}'
```

## Current Limits

- scale-out is intentionally capped at two replicas for the lab
- active-pressure target selection is still calibrated by sweep results and
  heuristics
- the spot interruption drill is synthetic `NodeClaim` deletion, not a
  cloud-native interruption notice
