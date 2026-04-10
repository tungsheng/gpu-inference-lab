# gpu-inference-lab Roadmap

## Project Objective

Build a production-style GPU inference platform on AWS using:

- Terraform
- Amazon EKS
- Karpenter
- Application Load Balancer
- real GPU model serving

## Target Architecture

```text
                 Internet
                    |
                    v
     ALB (Application Load Balancer)
                    |
                    v
              Kubernetes Ingress
                    |
                    v
              Inference Service
                    |
                    v
              Inference Pods
                    |
                    v
            Kubernetes Scheduler
                    |
                    v
                 Karpenter
                    |
                    v
             Dynamic GPU NodePool
```

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

Deliverables:

- Karpenter Terraform module
- controller IAM roles
- cluster-side Karpenter installation path

### Milestone 5 - GPU runtime prerequisites

Status: implemented.

Deliverables:

- NVIDIA device plugin
- GPU smoke test
- taints, tolerations, and `nvidia.com/gpu` scheduling contract

### Milestone 6 - Dynamic GPU serving path

Status: implemented.

Deliverables:

- Karpenter-managed GPU `NodePool`
- real vLLM inference deployment
- public inference edge
- default first-response validation flow
- optional autoscaling and load-test assets kept in-repo for manual experiments

### Milestone 7 - External inference edge

Status: implemented.

Deliverables:

- dedicated `vllm-openai` service and ingress manifests
- shared public ALB path for `/v1` inference traffic
- public endpoint reporting from `./scripts/up`
- first-successful-external-completion timing in `./scripts/verify`

### Milestone 8 - Production metrics and cold-start tradeoffs

Status: implemented as optional/manual assets.

Deliverables:

- system-node-group and Karpenter-only GPU-capacity guardrails
- Prometheus, Grafana, DCGM exporter, Pushgateway, and Prometheus Adapter manifests
- vLLM autoscaling from `vllm:num_requests_waiting` instead of CPU utilization
- optional scale-out and reporting assets that are no longer part of the default script path

## Planned Next Milestones

### Milestone 9 - Spot and on-demand GPU strategy

Status: planned.

### Milestone 10 - AZ distribution

Status: planned.

### Milestone 11 - GPU bin packing

Status: planned.

### Milestone 12 - Production hardening

Status: planned.
