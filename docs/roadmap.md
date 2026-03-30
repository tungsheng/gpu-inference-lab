# gpu-inference-lab Roadmap

## Project objective

Build a production-style GPU inference platform on AWS using:

- Terraform
- Amazon EKS
- Karpenter
- Application Load Balancer
- real GPU model serving

## Target architecture

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

## Implemented milestones

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
- load test that can trigger scale-out
- measured cold-start and scale-down workflow
- cost note comparing fixed and dynamic GPU baselines

## Planned next milestones

### Milestone 7 - Spot and on-demand GPU strategy

Status: planned.

### Milestone 8 - AZ distribution

Status: planned.

### Milestone 9 - GPU bin packing

Status: planned.

### Milestone 10 - Warm GPU pools

Status: planned.

### Milestone 11 - Observability

Status: planned.

### Milestone 12 - Production hardening

Status: planned.
