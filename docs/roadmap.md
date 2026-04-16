# GPU Inference Lab Roadmap

## Objective

Build a production-style GPU inference platform on AWS that teaches the right ML
infrastructure lessons:

- how public inference traffic reaches GPU-backed workloads
- how elastic GPU capacity is provisioned and cleaned up
- how observability feeds autoscaling and operator decisions
- how to reason about latency, utilization, and cost together

## Current State

The repo is now in a much stronger place. It proves two clear operator paths:

- `./scripts/verify` cold-starts the public inference edge from zero GPU nodes
- `./scripts/evaluate --profile zero-idle|warm-1` drives HPA scale-out, triggers
  a second GPU node, and writes latency, utilization, and cost reports

What is already implemented:

- Terraform-managed VPC and EKS environment in `infra/env/dev`
- AWS Load Balancer Controller plus a public ALB-backed inference ingress
- Karpenter-managed GPU capacity with no managed GPU node group
- separate on-demand and spot serving `NodePool`s
- a warm-node experiment path through `gpu-warm-placeholder`
- NVIDIA device plugin and a real vLLM deployment
- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  dashboards in the default scripted workflow
- Markdown and JSON experiment reports under `docs/reports/`

What is still not true:

- the environment is still dev-oriented, not production-hardened
- the HPA signal is not yet capacity-aware
- the repo does not yet prove GPU bin-packing efficiency
- spot interruption handling and deeper resilience experiments are still ahead

## Implemented Milestones

### Milestone 0 - Repository foundation

Status: implemented.

Outcome:

- repo layout, shell test surface, and a consistent workflow structure

### Milestone 1 - AWS networking

Status: implemented.

Outcome:

- VPC, public and private subnets, routing, Internet Gateway, and NAT for the
  dev environment

### Milestone 2 - EKS system plane

Status: implemented.

Outcome:

- Terraform-managed EKS control plane and managed system node group

### Milestone 3 - Public inference edge

Status: implemented.

Outcome:

- AWS Load Balancer Controller plus ALB-backed ingress for `/v1` traffic

### Milestone 4 - Dynamic GPU capacity

Status: implemented.

Outcome:

- Karpenter controller, CRDs, shared GPU `EC2NodeClass`, and serving
  `NodePool`s

### Milestone 5 - GPU runtime prerequisites

Status: implemented.

Outcome:

- NVIDIA device plugin and GPU scheduling rules for the serving workload

### Milestone 6 - Real GPU serving

Status: implemented.

Outcome:

- vLLM deployment serving a real model
- deployment-only cold-start proof through `./scripts/verify`

### Milestone 7 - Observability-driven evaluation

Status: implemented.

Outcome:

- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  dashboards in the default path
- HPA validation from `vllm_requests_running`
- report generation for first response, scale-out, latency, utilization, and
  cost

### Milestone 8 - Mixed-capacity serving profiles

Status: implemented.

Outcome:

- `gpu-serving-ondemand` and `gpu-serving-spot` as the real serving pools
- `warm-1` profile anchored on on-demand capacity
- zero-idle versus warm-node comparison as part of the scripted workflow

## Planned Next Milestones

### Milestone 9 - Capacity-aware autoscaling and saturation control

Status: planned.

Why this is next:

- the repo already proves dynamic provisioning, mixed capacity, and
  metrics-backed experiments
- the highest-value gap is the autoscaling signal itself
- `vllm_requests_running` captures admitted work, not total pressure

Completion should look like:

- a new active-pressure metric such as `waiting + running`
- an HPA target based on per-pod capacity instead of only running requests
- `./scripts/evaluate` comparing the current HPA and the new policy
- reports that highlight p95 latency, queue time, GPU utilization, number of
  GPU nodes, and burst cost

### Milestone 10 - GPU bin packing and multi-request efficiency

Status: planned.

Why this follows Milestone 9:

- once scaling is tied to a better pressure signal, the next question is how
  much useful work each GPU node can do

Completion should look like:

- experiments that show one GPU can sustain a measurable active-request load
- clearer reasoning about per-node GPU utilization and stranded capacity
- report language that explains why a node shape was efficient or wasteful

### Milestone 11 - Resilience and interruption handling

Status: planned.

Completion should look like:

- clearer behavior when spot is unavailable or interrupted
- stronger reasoning about AZ placement and capacity scarcity
- evaluation notes for how serving behaves during degraded capacity conditions

### Milestone 12 - Production hardening

Status: planned.

Completion should look like:

- private EKS endpoint access
- SSM, bastion, or VPN-based administration
- tighter public CIDR controls
- clearer operational and security guidance for production posture
