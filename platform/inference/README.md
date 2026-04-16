# platform/inference

This directory contains the manifests for the public inference surface:

- `vllm-openai.yaml`: GPU-bound vLLM deployment
- `hpa.yaml`: HPA for the deployment
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
- `./scripts/evaluate` applies the deployment and HPA to prove burst scale-out

## Scheduling Contract

The deployment is intentionally strict:

- `nodeSelector: workload=gpu`
- GPU taint toleration
- `nvidia.com/gpu: 1`

That forces the pod onto Karpenter-managed GPU capacity instead of allowing it
to land on system nodes.

## Autoscaling Today

The HPA depends on the observability stack because its current target metric is
`vllm_requests_running` from Prometheus Adapter.

That is the current repo truth:

- it proves the custom-metrics control loop works
- it does not yet represent the best autoscaling signal for bursty inference

The next docs and roadmap step is to promote an active-pressure metric such as
`waiting + running` into the HPA.
