# platform/inference

This directory contains the manifests for the public inference surface:

- `vllm-openai.yaml`: GPU-bound vLLM deployment
- `hpa.yaml`: running-request HPA baseline
- `hpa-active-pressure.yaml`: active-pressure HPA baseline
- `service.yaml`: stable in-cluster `ClusterIP` service
- `ingress.yaml`: public ALB-backed `/v1` route

## Current Behavior

The deployment uses:

- image `vllm/vllm-openai:v0.9.0`
- model `Qwen/Qwen2.5-0.5B-Instruct`
- served model name `qwen2.5-0.5b`
- one requested and limited GPU per replica

The scripts consume these manifests in different ways:

- `./scripts/up` applies only the service and ingress so the public edge exists
  before any GPU pod is launched
- `./scripts/verify` applies the deployment only to prove the cold-start path
- `./scripts/evaluate` applies the deployment plus the selected HPA policy to
  prove burst scale-out, runs both policies sequentially in compare mode, or
  sweeps active-pressure targets

## Scheduling Contract

The deployment is intentionally strict:

- `nodeSelector: workload=gpu`
- GPU taint toleration
- `nvidia.com/gpu: 1`

That forces the pod onto Karpenter-managed GPU capacity instead of allowing it
to land on system nodes.

## Autoscaling Today

The HPA depends on the observability stack because both policies read custom pod
metrics from Prometheus Adapter:

- `hpa.yaml` uses `vllm_requests_running`
- `hpa-active-pressure.yaml` uses `vllm_requests_active = waiting + running`

That is the current repo truth:

- it proves the custom-metrics control loop works with two signals
- it lets `./scripts/evaluate --policy compare` compare those signals directly
- it lets `./scripts/evaluate --policy sweep` calibrate active-pressure targets
