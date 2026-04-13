# Architecture

## Serving Topology

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Ingress (/v1)
   |
   v
vLLM Service
   |
   +--> vLLM Deployment
   |      |
   |      +--> HPA on vllm_requests_running (evaluate/manual path)
   |
   v
Karpenter-managed GPU nodes

Supporting control plane:
- AWS Load Balancer Controller
- Karpenter
- NVIDIA device plugin
- Prometheus
- Grafana
- Prometheus Adapter
- DCGM exporter
```

## Node Roles

- system nodes run the controllers and shared services
- `gpu-serving` is the zero-idle serving `NodePool`
- `gpu-warm-placeholder` is the warm-profile deployment that keeps one
  `gpu-serving` node alive without consuming the GPU

GPU nodes are still created only through Karpenter. There is no fixed managed
GPU node group.

## Scripted Lifecycle

- `./scripts/up` installs the public inference edge, observability stack, GPU
  capacity definitions, and runtime prerequisites, but does not apply the vLLM
  deployment or HPA
- `./scripts/verify` proves the first-response path and confirms the cluster
  returns to zero GPU nodes after cleanup
- `./scripts/evaluate` proves HPA-driven scale-out, second-node provisioning,
  and report generation for zero-idle versus warm-node profiles
- `./scripts/down` removes the runtime stack, observability stack, and
  Terraform infrastructure

## Design Intent

- keep the default compute baseline at zero idle GPU nodes
- prove cold-start behavior separately from burst behavior
- make operator visibility part of the default story instead of a manual add-on
- preserve a clean dev/prod boundary by calling out the public EKS API as a
  dev-only choice
