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
   Prometheus Adapter exposes both `vllm_requests_running` and
   `vllm_requests_active` as custom pod metrics, and
   `./scripts/evaluate --policy running|active-pressure|compare|sweep` uses
   those metrics to scale the deployment from `1` to `2` replicas during the
   burst experiment and to compare active-pressure targets across repeated
   runs.

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

The architecture now exposes and exercises both autoscaling signals, but it is
still a v1 control-loop experiment:

- active pressure is tuned with a simple per-pod target rather than a
  GPU-efficiency model
- queue behavior is estimated from waiting depth over request completion rate,
  with TTFT kept as a separate serving signal
- the next architectural step is GPU bin packing and per-GPU capacity reasoning
