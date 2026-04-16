# Architecture

## Platform Shape

```text
Client
   |
   v
AWS Application Load Balancer
   |
   v
Kubernetes Ingress (/v1)
   |
   v
ClusterIP Service
   |
   v
vLLM Pods
   |
   +--> HPA reads custom metric from Prometheus Adapter
   |
   +--> Prometheus scrapes vLLM and Karpenter metrics
   |
   +--> DCGM exporter reports GPU utilization
   |
   v
Karpenter launches matching GPU nodes
```

The repo separates steady system capacity from elastic serving capacity:

- managed system nodes run controllers and shared services
- Karpenter owns GPU nodes
- no managed GPU node group exists

## Main Building Blocks

| Layer | Components | Purpose |
| --- | --- | --- |
| Infrastructure | Terraform VPC and EKS modules | create the dev environment in `us-west-2` |
| Edge | AWS Load Balancer Controller, service, ingress | expose `/v1` publicly through an ALB |
| Serving | vLLM deployment, service, HPA | run an OpenAI-compatible inference endpoint |
| Capacity | Karpenter `EC2NodeClass` and `NodePool`s | provision and recycle GPU nodes on demand |
| Runtime | NVIDIA device plugin | advertise `nvidia.com/gpu` to scheduled workloads |
| Observability | Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter | support HPA, dashboards, and experiment reporting |

## Capacity Layout

The current serving model has three relevant capacity shapes:

- `gpu-serving-ondemand`: on-demand serving capacity, fallback path, and warm
  baseline anchor
- `gpu-serving-spot`: preferred burst capacity for new serving nodes
- `gpu-warm-placeholder`: a tiny deployment used only by the `warm-1` profile
  to keep one on-demand serving node alive

Both serving `NodePool`s share the same GPU `EC2NodeClass`, labels, taints, and
instance-family constraints. The difference is capacity type and scheduling
preference.

## Control Loops

There are three important feedback loops in the repo:

1. **Provisioning loop**
   Terraform creates AWS primitives, then `./scripts/up` installs controllers,
   observability, and GPU prerequisites.
2. **Scheduling loop**
   The vLLM deployment requests `nvidia.com/gpu: 1`, stays pending until
   Karpenter launches a matching node, and then becomes Ready once the NVIDIA
   device plugin exposes the GPU resource.
3. **Autoscaling loop**
   Prometheus Adapter exposes `vllm_requests_running` as a custom pod metric,
   and the HPA uses that metric to scale the deployment from `1` to `2`
   replicas during `./scripts/evaluate`.

## Why The Workflow Is Split

The repo deliberately separates two questions that are easy to blur together:

- `./scripts/verify` asks whether the public inference path works from a true
  zero-GPU baseline.
- `./scripts/evaluate` asks how the system behaves once traffic pressure is
  high enough to scale replicas and launch more GPU nodes.

That split keeps the default story clear:

- cold start and cleanup are easy to prove
- burst behavior has its own measurable workflow
- observability is part of the default path, not an optional side project

## Current Limitation

The architecture already exposes both waiting and running request metrics in
Prometheus, but only `vllm_requests_running` is wired into the HPA today. That
means autoscaling reacts to work that is already admitted instead of total
pressure. The next architectural step is to promote a capacity-aware active
pressure metric into the control loop.
