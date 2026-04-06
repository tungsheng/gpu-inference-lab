# Architecture

## Goal

This project demonstrates a production-style GPU inference platform on AWS that
keeps GPU cost elastic instead of paying for idle accelerator capacity.

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
   +-----------------------> sample HTTP pods on managed system nodes
   |
   +-----------------------> vLLM service on Karpenter GPU nodes

EKS cluster
   |
   +--> system managed node group -> m7i-flex.large -> workload=system
   |
   +--> Karpenter controller -> GPU NodePool -> g4dn.xlarge / g5.xlarge
                                      |
                                      +--> workload=gpu
                                      +--> gpu=true:NoSchedule
                                      +--> NVIDIA device plugin daemonset
```

Current implementation details:

- Terraform provisions the VPC, EKS cluster, and Karpenter IAM roles.
- `./scripts/dev up` installs the AWS Load Balancer Controller,
  metrics-server, Karpenter, the GPU `EC2NodeClass`/`NodePool`, the NVIDIA
  device plugin, and the public inference edge.
- The cluster always keeps system capacity on managed CPU nodes.
- The cluster starts with zero GPU worker nodes.
- The public ALB edge exists even before GPU pods are launched.
- Applying the vLLM deployment creates a pending GPU pod, which Karpenter
  converts into a `NodeClaim` and then an EC2 GPU instance.
- Under load, the HPA can request a second vLLM replica, which triggers a
  second GPU node.
- When load disappears and the pods scale down, Karpenter consolidates empty
  GPU nodes away.

## Operational characteristics

- Idle GPU cost is zero because there is no fixed GPU node group.
- The GPU fleet is constrained but flexible: `g4dn.xlarge` and `g5.xlarge`
  are both allowed.
- GPU scheduling stays explicit through `workload=gpu`,
  `gpu=true:NoSchedule`, and `nvidia.com/gpu: 1`.
- The serving path is now a real inference API instead of a `sleep` container.

## Implemented milestones

- Milestone 1: AWS networking layer
- Milestone 2: EKS cluster deployment
- Milestone 3: ingress and load balancer integration
- Milestone 4: Karpenter control-plane integration
- Milestone 5: GPU runtime prerequisites
- Milestone 6: dynamic GPU serving path
- Milestone 7: external inference edge
