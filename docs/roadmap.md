# gpu-inference-lab Roadmap

## Project Objective

Build a production-style GPU inference platform on AWS using:

- Terraform
- Amazon EKS
- Karpenter
- Application Load Balancer
- real GPU model serving

## Current State

The repository currently proves two operator-relevant paths:

- `./scripts/verify` can cold-start the public inference edge from zero GPU nodes
- `./scripts/evaluate --profile zero-idle|warm-1` can drive running-request-based HPA scale-out, trigger a second GPU node through Karpenter, and write latency, utilization, and cost reports

The default lifecycle today is:

- `./scripts/up`
- `./scripts/verify`
- `./scripts/evaluate --profile zero-idle`
- `./scripts/down`

What is already in place:

- Terraform-managed VPC and EKS cluster in `infra/env/dev`
- AWS Load Balancer Controller plus a public ALB-backed inference ingress
- Karpenter-managed GPU capacity with a zero-idle serving profile and a warm-node experiment profile
- NVIDIA device plugin and a real vLLM deployment
- Prometheus, Grafana, Prometheus Adapter, dashboards, Pushgateway, and DCGM exporter
- Markdown and JSON experiment reports under `docs/reports/`

What is not yet true:

- the current environment is still dev-oriented, not production-hardened
- GPU capacity is still on-demand only
- the project proves scale-out and tradeoffs, but not yet spot interruption handling, AZ-aware resilience, or GPU bin-packing efficiency

## Implemented Milestones

### Milestone 0 - Repository foundation

Status: implemented.

Outcome:

- initial repo layout, docs structure, and local validation workflow

### Milestone 1 - AWS networking layer

Status: implemented.

Outcome:

- VPC, public/private subnets, routing, and NAT for the dev environment

### Milestone 2 - EKS cluster deployment

Status: implemented.

Outcome:

- Terraform-managed EKS control plane and system node group

### Milestone 3 - Ingress and load balancer

Status: implemented.

Outcome:

- AWS Load Balancer Controller and a public ALB-backed Kubernetes ingress path

### Milestone 4 - Dynamic compute control plane

Status: implemented.

Outcome:

- Karpenter controller, CRDs, and GPU `EC2NodeClass` / `NodePool` definitions

### Milestone 5 - GPU runtime prerequisites

Status: implemented.

Outcome:

- NVIDIA device plugin and GPU scheduling rules for inference workloads

### Milestone 6 - Dynamic GPU serving path

Status: implemented.

Outcome:

- Karpenter-managed GPU `NodePool`
- real vLLM inference deployment
- deployment-only serving manifest at `platform/inference/vllm-openai.yaml`
- default first-response validation flow in `./scripts/verify`

### Milestone 7 - External inference edge

Status: implemented.

Outcome:

- dedicated `vllm-openai` service and ingress manifests
- shared public ALB path for `/v1` inference traffic
- public endpoint reporting from `./scripts/up`
- first-successful-external-completion timing in `./scripts/verify`

### Milestone 8 - Load-aware GPU serving with operator visibility

Status: implemented.

Outcome:

- Prometheus, Grafana, Prometheus Adapter, dashboards, Pushgateway, and DCGM exporter in the default `./scripts/up` path
- running-request-driven HPA validation from `vllm_requests_running`
- `./scripts/evaluate` for `zero-idle` and `warm-1` experiment profiles
- Markdown and JSON reports for first-response, scale-out, latency, GPU utilization, and cost tradeoffs
- explicit dev/prod boundary docs for public versus private EKS API access

## Planned Next Milestones

### Milestone 9 - Spot and on-demand GPU strategy

Status: planned.

Goal:

- make capacity type part of the real serving story instead of an all-on-demand baseline

Completion should look like:

- separate capacity rules for on-demand and spot GPU supply
- clear fallback behavior when spot is unavailable or interrupted
- an evaluation path that compares cost and latency implications of the chosen mix
- docs that explain which capacity type carries the warm baseline and which carries burst capacity

### Milestone 10 - AZ distribution

Status: planned.

Goal:

- reduce single-AZ dependence and make capacity behavior easier to reason about during shortages

Completion should look like:

- explicit multi-AZ expectations for system capacity and GPU capacity
- docs and configuration that explain how subnet and availability-zone choices affect scheduling
- evaluation notes on whether GPU provisioning behavior differs by AZ

### Milestone 11 - GPU bin packing

Status: planned.

Goal:

- prove that launched GPU nodes are a sensible fit for the workload shape, not just that they launch

Completion should look like:

- support for larger or more varied GPU shapes where packing tradeoffs are visible
- workload sizing and scheduling rules that allow multiple useful placement patterns
- observability that can explain per-node GPU utilization and stranded capacity
- a report or doc path that shows why a given node shape was efficient or wasteful

### Milestone 12 - Production hardening

Status: planned.

Goal:

- draw a credible line between the dev demo environment and a safer production-ready posture

Completion should look like:

- private EKS endpoint access and a documented SSM, bastion, or VPN administration path
- tighter public CIDR controls and stricter cluster access defaults
- clearer security and operational guidance for credentials, access, and rollback
- docs that distinguish what is intentionally simplified in dev from what production should require
