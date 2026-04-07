# platform/inference

This directory contains inference workload manifests, including:

- Deployments
- Services
- Ingresses
- Horizontal Pod Autoscaler resources

Current checked-in examples:

- `vllm-openai.yaml` for the GPU-bound vLLM `Deployment` and `HorizontalPodAutoscaler`
- `service.yaml` for the stable in-cluster `vllm-openai` `ClusterIP` service
- `ingress.yaml` for the public ALB-backed `/v1` inference path

The current serving stack uses the official `vllm/vllm-openai` image to expose
an OpenAI-compatible API backed by the small public model
`Qwen/Qwen2.5-0.5B-Instruct`.

The workload manifest includes:

- a GPU-bound `Deployment`
- a CPU-based `HorizontalPodAutoscaler` that can request a second GPU replica
  under load once metrics-server is installed
