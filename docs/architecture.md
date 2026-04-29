# Architecture

## Platform Shape

```text
Client
   |
   v
AWS Application Load Balancer
   |
   v
Ingress (/v1)
   |
   v
ClusterIP Service
   |
   v
vLLM pod
   |
   +--> HPA reads custom pod metrics from Prometheus Adapter
   |
   +--> Prometheus, Grafana, Pushgateway, and DCGM support reporting
   |
   v
Karpenter launches matching GPU nodes
```

The platform separates always-on system capacity from elastic serving capacity:

- managed system nodes run controllers and shared services
- Karpenter owns GPU nodes
- no managed GPU node group exists

## Building Blocks

| Layer | Components | Purpose |
| --- | --- | --- |
| Infrastructure | Terraform VPC and EKS modules | create the dev environment in `us-west-2` |
| Edge | AWS Load Balancer Controller, service, ingress | expose `/v1` through a public ALB |
| Serving | vLLM deployment and HPA policies | run and scale an OpenAI-compatible inference endpoint |
| Capacity | Karpenter `EC2NodeClass` and serving `NodePool`s | provision and recycle GPU nodes on demand |
| Runtime | NVIDIA device plugin | advertise `nvidia.com/gpu` to scheduled workloads |
| Observability | Prometheus, Grafana, Adapter, Pushgateway, DCGM | support HPA, dashboards, and reports |

## Capacity Layout

The active serving model has three relevant pieces:

- `gpu-serving-ondemand`: warm baseline and fallback serving path
- `gpu-serving-spot`: preferred fresh burst capacity
- `gpu-warm-placeholder`: `warm-1` helper that keeps one on-demand serving node
  alive without consuming the GPU

Both serving `NodePool`s share the same GPU `EC2NodeClass`, labels, taints, and
instance-family constraints. Capacity type and scheduling weight are the main
differences.

## Control Loops

Provisioning loop:

- Terraform creates AWS primitives.
- `./scripts/up` installs controllers, observability, Karpenter, GPU runtime
  prerequisites, service, and ingress.

Scheduling loop:

- the vLLM pod requests `nvidia.com/gpu: 1`
- it stays pending until Karpenter launches matching capacity
- the NVIDIA device plugin exposes the GPU resource
- the pod starts, loads the model, and becomes Ready

Autoscaling loop:

- Prometheus scrapes vLLM metrics
- Prometheus Adapter exposes `vllm_requests_running` and
  `vllm_requests_active`
- HPA scales the deployment from one to two replicas during evaluation runs
- reports capture timing, latency, pressure, capacity type, and cost signals

## Why The Workflow Is Split

`./scripts/verify` answers whether the public inference path works from zero
GPU nodes.

`./scripts/evaluate` answers how the system behaves under burst pressure,
including HPA signal choice, active-target calibration, mixed-capacity fallback,
and synthetic interruption recovery.

That split keeps cold-start validation fast while giving burst behavior its own
measurable workflow.

## Current Limits

- active-pressure tuning is heuristic
- queue wait is derived rather than directly measured
- GPU packing has not been compared across multiple node or placement shapes
- the active environment is a dev topology, not a production-hardened topology
