# Scaling

## Current state

The current repository does not yet implement elastic compute. The EKS module provisions a fixed managed node group, and the sample workload does not use GPU resources.

What exists today:

- An EKS managed node group for baseline cluster capacity.
- A public sample workload behind an ALB.
- No Karpenter controller.
- No GPU device plugin.
- No Horizontal Pod Autoscaler.

## Core scaling model for this project

The most important control flow to understand is:

```text
traffic increases
        |
        v
more pods are created
        |
        v
pods are unschedulable
        |
        v
Karpenter observes pending pods
        |
        v
EC2 instances launch
        |
        v
nodes join EKS
        |
        v
pods are scheduled
```

Two different scaling loops matter:

- Workload scaling creates more pods. That is the job of the Horizontal Pod Autoscaler or another workload-level controller.
- Capacity scaling creates more nodes. That is the job of Karpenter once pending pods cannot be placed.

## Roadmap sequence

Milestone 4:

- Install Karpenter.
- Define the first `EC2NodeClass`.
- Define the first `NodePool`.
- Demonstrate scale from zero for a pending GPU workload.

Milestone 5:

- Add GPU node requirements.
- Add taints, tolerations, and explicit GPU resource requests.
- Install the NVIDIA device plugin and related runtime support.

Milestone 6:

- Support heterogeneous GPU instance types so provisioning can adapt to price and capacity.

Milestone 8:

- Add availability-zone-aware scheduling and provisioning constraints.

Milestone 10:

- Maintain warm GPU capacity to reduce cold-start latency.

Milestone 12:

- Add workload-level autoscaling with HPA and production-relevant metrics.

## Questions this project should be able to answer

- What signal causes a GPU node to launch
- How Karpenter discovers subnets and security groups
- How IAM permissions allow Karpenter to provision EC2 instances
- How GPU scheduling is enabled inside Kubernetes
- When warm pools are worth the extra idle cost

## Acceptance criteria for the next scaling milestone

The next scaling milestone is complete when the repository can demonstrate:

- Zero GPU nodes before the workload is created.
- A pending GPU pod with `nvidia.com/gpu` requests.
- Automatic node launch by Karpenter.
- Successful pod scheduling onto the new node.
- Node removal after the workload becomes idle.
