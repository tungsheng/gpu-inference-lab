# Architecture

## Goal

This project is building toward a production-style GPU inference platform on AWS. The current repository implements the base control-plane and networking pieces needed before GPU-serving workloads and Karpenter-driven autoscaling are added.

## Current implemented architecture

```text
Internet
   |
   v
ALB
   |
   v
Kubernetes Ingress
   |
   v
Service
   |
   v
Sample Pods
   |
   v
EKS Managed Node Group
```

Current implementation details:

- The VPC and EKS cluster are provisioned with Terraform.
- Worker nodes run in private subnets.
- The AWS Load Balancer Controller installs after Terraform apply and manages the ALB created by the ingress resource.
- The sample workload is `hashicorp/http-echo`, which exists to validate ingress and cluster plumbing rather than real inference behavior.

## Target architecture

```text
Internet
   |
   v
ALB
   |
   v
Ingress
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
GPU Node Pools
```

Target operational characteristics:

- GPU nodes scale from pending workloads instead of staying permanently provisioned.
- Multiple GPU instance types can satisfy the same workload requirements.
- Spot and on-demand capacity can coexist.
- Observability and hardening are part of the platform design, not follow-on cleanup.

## Implemented milestones

- Milestone 1: AWS networking layer
- Milestone 2: EKS cluster deployment
- Milestone 3: ingress and load balancer integration

## Next architecture change

The next material change is Milestone 4: introduce Karpenter and the first GPU-capable provisioning path. That will replace the current fixed-capacity mental model with a pending-pod-to-new-node lifecycle.
