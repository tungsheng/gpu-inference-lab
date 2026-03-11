# GPU Inference Lab

**gpu-inference-lab** is a hands-on project that builds a production-style machine learning inference platform on AWS.

The target platform combines **Terraform**, **Amazon EKS**, **Karpenter**, **Application Load Balancer**, and GPU-serving workloads. The current repository implements the infrastructure foundation: VPC networking, an EKS cluster, ALB-backed ingress, and a sample Kubernetes service.

The project focuses on the **infrastructure foundations required for ML platforms**, including:

- VPC networking with public/private subnets and NAT routing
- Kubernetes ingress and ALB integration
- IAM roles and IRSA for secure service access
- Elastic compute patterns for inference workloads
- Containerized serving infrastructure

This repository is structured as a **learning lab and reference architecture** for building scalable ML inference systems.

## Current status

The repository currently covers the platform foundation milestones:

- Milestone 1: AWS networking layer
- Milestone 2: EKS cluster deployment
- Milestone 3: ingress and load balancer integration

The next major milestone is dynamic GPU compute with Karpenter.

## Docs

- [Roadmap](docs/roadmap.md)
- [Architecture](docs/architecture.md)
- [Networking](docs/networking.md)
- [Scaling](docs/scaling.md)
- [Inference](docs/inference.md)
- [Cost optimization](docs/cost-optimization.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Operations](docs/operations.md)
- [Dev environment workflow](docs/dev-environment.md)

## Quick start

Initialize Terraform:

```bash
terraform -chdir=infra/env/dev init
```

Apply infra and Kubernetes resources:

```bash
./scripts/apply-dev.sh
```

Destroy the full dev environment:

```bash
./scripts/destroy-dev.sh
```

## Useful checks

```bash
kubectl get pods -n kube-system
kubectl get all -n app
kubectl get ingress -n app -o wide
```
