# Inference

## What Lives Here

The repo uses a real GPU inference service.

This part of the repo includes:

- a deployment-only vLLM manifest at `platform/inference/vllm-openai.yaml`
- a running-request-driven HPA at `platform/inference/hpa.yaml`
- a dedicated `ClusterIP` service at `platform/inference/service.yaml`
- a public ALB ingress at `platform/inference/ingress.yaml`

The scripts use those manifests in different ways:

- `./scripts/up` prepares the GPU `NodePool`, NVIDIA device plugin,
  observability stack, service, and ingress
- `./scripts/verify` applies only `platform/inference/vllm-openai.yaml`
- `./scripts/evaluate` applies both `platform/inference/vllm-openai.yaml` and
  `platform/inference/hpa.yaml`

## Serving Stack

- image: `vllm/vllm-openai:v0.9.0`
- model: `Qwen/Qwen2.5-0.5B-Instruct`
- served model name: `qwen2.5-0.5b`

Why this stack:

- vLLM is representative of current GPU LLM serving patterns
- it exposes a stable HTTP API instead of a shell command or sleep loop
- the model is small enough to fit on the single-GPU node types used in this lab

## Scheduling Contract

The deployment depends on the same explicit scheduling rules the rest of the
platform is built around:

- `nodeSelector: workload=gpu`
- `gpu=true:NoSchedule` toleration
- `requests.nvidia.com/gpu: 1`
- `limits.nvidia.com/gpu: 1`

That means the workload stays pending until:

1. Karpenter creates matching capacity
2. the EC2 GPU node joins the cluster
3. the NVIDIA device plugin advertises `nvidia.com/gpu`

## Default Validation

Use the scripted path:

```bash
./scripts/up
./scripts/verify
```

`./scripts/verify` is the default proof that the public inference edge works
from a zero-GPU baseline.

## Load-Aware Validation

Use the evaluation path:

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
```

That flow proves:

- the HPA can scale from `1` to `2` replicas from `vllm_requests_running`
- Karpenter can add a second GPU node in response
- `warm-1` can keep one `gpu-serving` node alive with the tiny
  `platform/tests/gpu-warm-placeholder.yaml` deployment
- Prometheus can report latency, queue, throughput, and GPU-utilization metrics
- the repo can compare zero-idle and warm-node tradeoffs with report files

## Manual Validation

After `./scripts/up`, apply the serving workload manually:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
kubectl apply -f platform/inference/hpa.yaml
```

Watch scheduling and autoscaling:

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,node.kubernetes.io/instance-type -w
```

If the public ingress is already provisioned, test the edge from your machine:

```bash
EDGE_HOST=$(kubectl get ingress vllm-openai-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${EDGE_HOST}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-0.5b","prompt":"Say hello from the public edge.","max_tokens":32,"temperature":0}'
```
