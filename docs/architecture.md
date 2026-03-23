# Architecture

## Goal

This project is building toward a production-style GPU inference platform on
AWS. The current repository now includes the first strict compute split:
separate CPU system nodes and GPU inference nodes, plus the cluster-side GPU
runtime wiring needed to validate scheduling.

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
   +-----------------------> sample HTTP pods on system nodes
   |
   +-----------------------> GPU validation/inference pods on GPU nodes

EKS cluster
   |
   +--> system managed node group -> m7i-flex.large -> workload=system
   |
   +--> gpu managed node group -> g4dn.xlarge -> workload=gpu + gpu=true:NoSchedule
                                  |
                                  v
                        NVIDIA device plugin daemonset
```

Current implementation details:

- The VPC and EKS cluster are provisioned with Terraform.
- Worker nodes run in private subnets.
- The AWS Load Balancer Controller installs after Terraform apply and manages
  the ALB created by the ingress resource.
- The baseline helper also installs a checked-in NVIDIA device plugin manifest
  that targets only tainted GPU nodes.
- The sample workload is still `hashicorp/http-echo`, which validates ingress
  and cluster plumbing.
- GPU validation happens separately through `platform/tests/gpu-test.yaml` and
  the placeholder deployment at `platform/inference/gpu-inference.yaml`.

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
- Milestone 5: fixed GPU scheduling baseline

## Next architecture change

The next material change is optional dynamic compute with Karpenter. That work
would replace the current fixed GPU desired size with a pending-pod-to-new-node
lifecycle, while keeping the existing system/GPU separation intact.
