# Inference

## Current state

The current repository still does not run a real ML inference server, but it
now does include the baseline GPU platform prerequisites.

What is already in place:

- a dedicated managed GPU node group (`g4dn.xlarge`)
- a checked-in NVIDIA device plugin manifest applied by `./scripts/apply-dev.sh`
- a smoke-test pod at `platform/tests/gpu-test.yaml`
- a placeholder GPU-bound deployment at `platform/inference/gpu-inference.yaml`

What is still missing before this becomes a real inference stack:

- A real inference container
- A stable service and ingress path for that container
- Request/response validation beyond `nvidia-smi`
- Operational validation beyond simple HTTP reachability

## Milestone 11 target

Milestone 11 introduces the first real inference service. Candidate runtimes include:

- vLLM
- Triton Inference Server
- TorchServe

The choice should be made based on the kind of model the lab wants to demonstrate:

- vLLM is a strong fit for large language model serving.
- Triton is a strong fit for mixed framework support and production inference patterns.
- TorchServe is simpler but less representative of current high-demand GPU serving stacks.

## Minimum requirements for the first inference service

- A container image that exposes a stable API.
- A deployment manifest under `platform/inference/`.
- A service and ingress path that can be exercised through the ALB.
- GPU requests and scheduling constraints that match the current GPU node policy.
- A smoke test that confirms the path from client request to model response.

The repository now includes an initial GPU-bound placeholder deployment at
`platform/inference/gpu-inference.yaml` to validate taints, tolerations, and
`nvidia.com/gpu` requests before a real inference server is introduced.

## Relationship to other milestones

- Milestone 4 provides optional elastic node provisioning.
- Milestone 5 provides the current fixed GPU scheduling baseline.
- Milestone 11 provides the real inference workload.
- Milestone 12 adds autoscaling behavior tied to inference demand.

Until those pieces exist together, this project should be described as a platform foundation for GPU inference rather than a completed GPU inference platform.
