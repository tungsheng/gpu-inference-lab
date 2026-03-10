# GPU Inference Lab

**gpu-inference-lab** is a hands-on project that builds a production-style machine learning inference platform on AWS.

The system deploys a cloud-native stack using **Terraform** and **Kubernetes**, running on **AWS EKS**. The platform exposes model inference APIs through an **ALB (Application Load Balancer)** and dynamically scales compute resources to support GPU workloads.

The project focuses on the **infrastructure foundations required for ML platforms**, including:

- VPC networking with public/private subnets and NAT routing
- Kubernetes ingress and ALB integration
- IAM roles and IRSA for secure service access
- Autoscaling compute nodes for inference workloads
- Containerized model serving infrastructure

This repository is structured as a **learning lab and reference architecture** for building scalable ML inference systems.

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
