# GPU Inference Lab

GPU Inference Lab is a hands-on AWS EKS project for learning how an elastic GPU
inference platform behaves under cold start, burst load, and mixed-capacity
serving pressure.

The repo proves two real operator paths today:

- `./scripts/verify` cold-starts the public inference edge from zero GPU nodes
  and returns the cluster to zero GPU nodes after cleanup.
- `./scripts/evaluate --profile zero-idle|warm-1` applies vLLM plus HPA, runs
  burst load, captures latency and utilization signals, and writes Markdown and
  JSON reports under `docs/reports/`.

## Platform At A Glance

```text
Internet
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
vLLM Deployment
   |
   +--> HPA on vllm_requests_running
   |
   +--> Prometheus / Grafana / Prometheus Adapter / Pushgateway
   |
   v
Karpenter-managed GPU nodes
   |
   +--> gpu-serving-ondemand
   +--> gpu-serving-spot

EKS cluster
   |
   +--> managed system nodes (m7i-flex.large)
   +--> no managed GPU node group
```

## Current Stack

- Terraform-managed VPC and EKS dev environment in `infra/env/dev`
- Managed system node group for controllers and shared services
- Karpenter-owned GPU capacity only, with no fixed managed GPU node group
- Shared GPU `EC2NodeClass` plus `gpu-serving-ondemand` and `gpu-serving-spot`
  `NodePool`s
- Real vLLM serving with `vllm/vllm-openai:v0.9.0` and
  `Qwen/Qwen2.5-0.5B-Instruct`
- Public ALB-backed inference edge through Kubernetes `Ingress`
- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  Grafana dashboards
- A `warm-1` profile that keeps one on-demand serving node alive through the
  lightweight `gpu-warm-placeholder` deployment

## Quick Start

Prerequisites:

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- access to `us-west-2`

Bring the dev environment up:

```bash
./scripts/up
```

Prove the zero-GPU cold-start path:

```bash
./scripts/verify
```

Run the burst evaluation path:

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
```

Tear everything down:

```bash
./scripts/down
```

Run the local shell tests:

```bash
./test/run.sh
```

## What The Scripts Do

- `./scripts/up` applies Terraform, connects kubeconfig, installs the AWS Load
  Balancer Controller, observability stack, Karpenter, GPU prerequisites, and
  the public inference service plus ingress. It leaves GPU node count at `0`.
- `./scripts/verify` applies only the vLLM deployment, waits for one GPU node,
  one Ready replica, and one successful external completion, then deletes the
  workload and waits for GPU cleanup back to `0`.
- `./scripts/evaluate` applies the vLLM deployment and HPA, runs the checked-in
  burst load, waits for a second replica and second GPU node, collects
  Prometheus and DCGM metrics, estimates serving-node cost, and writes reports.
- `./scripts/down` removes runtime resources, observability, GPU capacity
  definitions, controllers, and Terraform-managed infrastructure.

## What The Evaluation Path Answers

- How long does the first GPU node take to appear from a zero-idle baseline?
- How long does the first public completion take to succeed?
- Can `vllm_requests_running` drive HPA scale-out from one to two replicas?
- Does replica growth trigger a second Karpenter `NodeClaim` and second GPU
  node?
- What do p95 request latency, p95 time to first token, token throughput, and
  GPU utilization look like during a controlled burst?
- What is the tradeoff between `zero-idle` and `warm-1` for latency and serving
  cost?

## Current Limitation

The HPA currently scales from `vllm_requests_running`. That proves the control
loop works, but it reacts to admitted work rather than total pressure. The next
high-leverage step for the project is capacity-aware autoscaling based on
active pressure such as `waiting + running`, then comparing the current and new
policies in `./scripts/evaluate`.

## Dev Boundary

The active environment is intentionally dev-oriented:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

That is a convenience for fast iteration, not the target production posture. A
production variant should move to private cluster access plus SSM, bastion, or
VPN-based administration and tighter public CIDR controls.

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable VPC, EKS, and Karpenter Terraform modules
- `platform/inference/`: vLLM deployment, service, ingress, and HPA manifests
- `platform/karpenter/`: GPU `EC2NodeClass` and `NodePool` manifests
- `platform/observability/`: Prometheus, Grafana, adapter, exporter, and
  dashboard assets
- `platform/tests/`: manual GPU smoke test, load generator, and warm placeholder
- `platform/system/`: cluster-level runtime prerequisites such as the NVIDIA
  device plugin
- `scripts/`: lifecycle commands and shared shell helpers
- `docs/`: repo-level architecture, workflow, scaling, networking, and roadmap
  documentation

## Documentation

Start here:

- [Dev environment workflow](docs/dev-environment.md)
- [Operations](docs/operations.md)

Platform deep dives:

- [Architecture](docs/architecture.md)
- [Inference](docs/inference.md)
- [Scaling](docs/scaling.md)
- [Cost optimization](docs/cost-optimization.md)
- [Networking](docs/networking.md)

Background and next steps:

- [Dynamic GPU serving](docs/dynamic-gpu-serving.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Roadmap](docs/roadmap.md)
