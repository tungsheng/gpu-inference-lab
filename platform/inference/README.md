# platform/inference

This directory contains inference workload manifests, including:

- Deployments
- Services
- Horizontal Pod Autoscaler resources
- Smoke-test or validation manifests

Current checked-in examples:

- `vllm-openai.yaml` for the real GPU-backed serving path

The current serving stack uses the official `vllm/vllm-openai` image to expose
an OpenAI-compatible API backed by the small public model
`Qwen/Qwen2.5-0.5B-Instruct`.

The manifest includes:

- a GPU-bound `Deployment`
- a `ClusterIP` service
- a CPU-based `HorizontalPodAutoscaler` that can request a second GPU replica
  under load once metrics-server is installed
