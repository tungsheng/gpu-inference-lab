# platform/inference

This directory contains inference workload manifests, including:

- Deployments
- Services
- Horizontal Pod Autoscaler resources
- Smoke-test or validation manifests

Current checked-in examples:

- `gpu-inference.yaml` for the first tainted GPU deployment path

This placeholder deployment is intentionally simple. It validates GPU
scheduling, taints, tolerations, and `nvidia.com/gpu` requests before a real
inference server is introduced.
