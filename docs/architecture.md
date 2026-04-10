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
   v
vLLM Deployment + HPA
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
- `gpu-warm-1` is the warm-profile experiment `NodePool`

GPU nodes are still created only through Karpenter. There is no fixed managed
GPU node group.

## Scripted Lifecycle

- `./scripts/up` installs the public inference edge, observability stack, GPU
  capacity definitions, and runtime prerequisites
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
