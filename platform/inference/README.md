# platform/inference

This directory contains the serving workload manifests:

- `vllm-openai.yaml` for the GPU-bound vLLM `Deployment`
- `hpa.yaml` for the queue-depth-driven `HorizontalPodAutoscaler`
- `service.yaml` for the stable in-cluster `vllm-openai` `ClusterIP` service
- `ingress.yaml` for the public ALB-backed `/v1` inference path

The current serving stack uses the official `vllm/vllm-openai` image to expose
an OpenAI-compatible API backed by `Qwen/Qwen2.5-0.5B-Instruct`.

The script roles are:

- `./scripts/up` applies the service and ingress so the public edge exists
  before any GPU workload is launched
- `./scripts/verify` applies the deployment-only manifest to prove cold start
- `./scripts/evaluate` applies both the deployment and HPA to prove burst
  scale-out

The HPA depends on the observability stack installed by `./scripts/up`, because
its target metric is `vllm_requests_waiting` from Prometheus Adapter.
