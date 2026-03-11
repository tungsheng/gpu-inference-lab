# Inference

## Current state

The current repository does not yet run a real ML inference server. The only deployed application is a small `http-echo` service used to validate cluster networking and ingress.

That means the repository still needs all of the following before it can claim GPU inference support:

- A real inference container
- GPU runtime support in the cluster
- GPU resource requests in workload manifests
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
- GPU requests and scheduling constraints that match the Karpenter node policy.
- A smoke test that confirms the path from client request to model response.

## Relationship to other milestones

- Milestone 4 provides elastic node provisioning.
- Milestone 5 provides GPU scheduling.
- Milestone 11 provides the real inference workload.
- Milestone 12 adds autoscaling behavior tied to inference demand.

Until those pieces exist together, this project should be described as a platform foundation for GPU inference rather than a completed GPU inference platform.
