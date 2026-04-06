# Networking

## Current network design

The current dev environment provisions:

- One VPC in `us-west-2`
- Two public subnets
- Two private subnets
- One Internet Gateway
- One NAT Gateway
- Public and private route tables

The current CIDR layout in `infra/env/dev/main.tf` is:

- VPC: `10.0.0.0/16`
- Public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- Private subnets: `10.0.11.0/24`, `10.0.12.0/24`
- Availability zones: `us-west-2a`, `us-west-2c`

## Packet flow

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

## Public vs private subnets

Public subnets:

- Host the NAT Gateway.
- Are tagged for internet-facing load balancers.
- Allow ALB resources to be created by the AWS Load Balancer Controller.

Private subnets:

- Host the EKS worker nodes.
- Are tagged for internal Kubernetes load balancer discovery.
- Keep node networking off the public internet even when the application itself is publicly reachable.

## Why NAT and IGW both exist

- The Internet Gateway gives public subnet resources direct internet connectivity.
- The NAT Gateway lets private subnet nodes reach external services for package pulls, control-plane communication, and image downloads without assigning them public IPs.

## Current ingress implementation

The current public entry path is implemented with:

- `platform/controller/aws-load-balancer-controller/service-account.yaml`
- Helm release `aws-load-balancer-controller` from the `eks` chart repository
- `platform/test-app/service.yaml`
- `platform/test-app/ingress.yaml`
- `platform/inference/service.yaml`
- `platform/inference/ingress.yaml`

The current edge uses a shared internet-facing ALB and IP targets:

- `/` routes to the sample echo app
- `/v1` routes to the real `vllm-openai` inference service

This validates not just controller permissions and subnet tagging, but also the
real inference traffic path from ALB to the GPU-backed service.

## Roadmap impact

Networking work is foundational for later milestones:

- Karpenter will need subnet and security group discovery for new nodes.
- GPU nodes should continue to run in private subnets.
- Multi-AZ GPU strategies will depend on the subnet and route table layout created here.
