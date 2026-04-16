# Networking

## Current Network Layout

The dev environment provisions one VPC in `us-west-2` with:

- two public subnets
- two private subnets
- one Internet Gateway
- one NAT Gateway
- separate public and private route tables

Current CIDR plan from `infra/env/dev/main.tf`:

- VPC: `10.0.0.0/16`
- public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- private subnets: `10.0.11.0/24`, `10.0.12.0/24`
- availability zones: `us-west-2a`, `us-west-2c`

## Why The Layout Matters

The repo is testing a public inference edge without putting worker nodes
directly on the public internet:

- the ALB is created in public subnets
- EKS worker nodes live in private subnets
- outbound internet access from worker nodes uses the NAT Gateway

That gives the project a realistic edge-to-private-workload topology.

## Traffic Paths

Inbound inference traffic:

```text
Client
   |
   v
Internet-facing ALB
   |
   v
Kubernetes Ingress
   |
   v
ClusterIP Service
   |
   v
Pods on private-subnet worker nodes
```

Outbound traffic from worker nodes:

```text
Private subnet node
   |
   v
Private route table
   |
   v
NAT Gateway
   |
   v
Internet Gateway
   |
   v
Internet
```

## Subnet Tagging

The VPC module applies the tags the platform needs:

- public subnets are tagged for internet-facing load balancers
- private subnets are tagged for internal load balancers and Karpenter
  discovery
- the cluster tag is applied to both public and private subnets

Those tags are what let the AWS Load Balancer Controller and Karpenter place
their resources correctly.

## Inference Edge

The public inference path is assembled from:

- the AWS Load Balancer Controller Helm release
- `platform/inference/service.yaml`
- `platform/inference/ingress.yaml`

The ingress is configured as:

- ALB-backed
- internet-facing
- path prefix `/v1`
- target type `ip`

That means the repo is validating a real HTTP serving edge, not just cluster
reachability or controller installation.

## Dev Control Plane Boundary

The active environment keeps the EKS API public:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

This is a deliberate dev convenience for local iteration and demos. It should
not be mistaken for the production answer.

## Production Direction

A harder production posture should move toward:

- private cluster endpoint access
- SSM Session Manager, bastion, or VPN-based administration
- narrower public CIDR allowlists
- a clearer split between public inference traffic and private operator access
