# Architecture

## Goal

This project demonstrates a production-style GPU inference platform on AWS that
keeps GPU cost elastic instead of paying for idle accelerator capacity.

## Default Architecture

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
vLLM Service
   |
   v
vLLM Pod on Karpenter GPU Node

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

Default implementation details:

- Terraform provisions the VPC, EKS cluster, and IAM roles.
- `./scripts/up` installs the AWS Load Balancer Controller, Karpenter, the GPU
  `EC2NodeClass` and `NodePool`, the NVIDIA device plugin, and the public
  inference edge.
- The cluster always keeps system capacity on managed CPU nodes.
- The cluster starts with zero GPU worker nodes.
- The public ALB edge exists before GPU pods are launched.
- Applying the vLLM deployment creates a pending GPU pod, which Karpenter turns
  into a GPU instance.
- `./scripts/verify` proves the first-response path and confirms the cluster
  returns to zero GPU nodes after cleanup.

## Optional Layers

These remain in the repo, but they are no longer part of the default scripted
path:

- `platform/inference/hpa.yaml` for queue-depth-driven autoscaling
- `platform/observability/` for Prometheus, Grafana, DCGM exporter, and related
  dashboards
- `platform/tests/gpu-load-test.yaml` for manual scale-out pressure

## Operational Characteristics

- Idle GPU cost is zero because there is no fixed GPU node group.
- The GPU fleet is constrained but flexible: `g4dn.xlarge` and `g5.xlarge`
  are both allowed.
- GPU scheduling stays explicit through `workload=gpu`,
  `gpu=true:NoSchedule`, and `nvidia.com/gpu: 1`.
- The default automated workflow optimizes for bring-up, first-response proof,
  and clean teardown.
