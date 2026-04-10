# gpu-inference-lab Roadmap

## Project Objective

Build a production-style GPU inference platform on AWS using:

- Terraform
- Amazon EKS
- Karpenter
- Application Load Balancer
- real GPU model serving

## Implemented Milestones

### Milestone 0 - Repository foundation

Status: implemented.

### Milestone 1 - AWS networking layer

Status: implemented.

### Milestone 2 - EKS cluster deployment

Status: implemented.

### Milestone 3 - Ingress and load balancer

Status: implemented.

### Milestone 4 - Dynamic compute control plane

Status: implemented.

### Milestone 5 - GPU runtime prerequisites

Status: implemented.

### Milestone 6 - Dynamic GPU serving path

Status: implemented.

Deliverables:

- Karpenter-managed GPU `NodePool`
- real vLLM inference deployment
- public inference edge
- default first-response validation flow

### Milestone 7 - External inference edge

Status: implemented.

Deliverables:

- dedicated `vllm-openai` service and ingress manifests
- shared public ALB path for `/v1` inference traffic
- public endpoint reporting from `./scripts/up`
- first-successful-external-completion timing in `./scripts/verify`

### Milestone 8 - Load-aware GPU serving with operator visibility

Status: implemented.

Deliverables:

- Prometheus, Grafana, Prometheus Adapter, dashboards, and DCGM exporter in the default `./scripts/up` path
- queue-depth-driven HPA validation from `vllm_requests_waiting`
- `./scripts/evaluate` for `zero-idle` and `warm-1` experiment profiles
- Markdown and JSON reports for first-response, scale-out, latency, GPU utilization, and cost tradeoffs
- explicit dev/prod boundary docs for public versus private EKS API access

## Planned Next Milestones

### Milestone 9 - Spot and on-demand GPU strategy

Status: planned.

### Milestone 10 - AZ distribution

Status: planned.

### Milestone 11 - GPU bin packing

Status: planned.

### Milestone 12 - Production hardening

Status: planned.
