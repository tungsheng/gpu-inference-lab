# Networking

## Current Network Design

The current dev environment provisions:

- one VPC in `us-west-2`
- two public subnets
- two private subnets
- one Internet Gateway
- one NAT Gateway
- public and private route tables

The current CIDR layout in `infra/env/dev/main.tf` is:

- VPC: `10.0.0.0/16`
- public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- private subnets: `10.0.11.0/24`, `10.0.12.0/24`
- availability zones: `us-west-2a`, `us-west-2c`

## Packet Flow

Ingress flow:

```text
Client
   |
   v
AWS ALB
   |
   v
Kubernetes Ingress
   |
   v
ClusterIP Service
   |
   v
Pods in private-subnet worker nodes
```

Egress flow from worker nodes:

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

## Public vs Private Subnets

Public subnets:

- host the NAT Gateway
- are tagged for internet-facing load balancers
- allow ALB resources to be created by the AWS Load Balancer Controller

Private subnets:

- host the EKS worker nodes
- host both system and GPU nodes
- keep node networking off the public internet even when the application is publicly reachable

## Current Dev Endpoint Choice

The dev environment keeps the EKS API public:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

That choice is intentional for fast local iteration and easier demos, but it is
**not** the production recommendation.

## Production Alternative

A production-ready access model should move toward:

- private cluster endpoint access
- SSM Session Manager, bastion, or VPN-based admin access
- narrower CIDR allowlists for any remaining public exposure

## Inference Edge

The current public inference path is implemented with:

- `platform/controller/aws-load-balancer-controller/service-account.yaml`
- Helm release `aws-load-balancer-controller`
- `platform/inference/service.yaml`
- `platform/inference/ingress.yaml`

This validates the real inference traffic path from ALB to the GPU-backed
service, not just controller installation.
