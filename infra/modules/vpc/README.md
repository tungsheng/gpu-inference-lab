# infra/modules/vpc

This module is a thin wrapper around `terraform-aws-modules/vpc/aws`.

Its job is to keep the repo's VPC interface simple while still applying the
tags and subnet structure the platform needs.

## Current Behavior

- one VPC
- explicit public and private subnet CIDRs
- one public and one private subnet per availability zone
- a single NAT Gateway shared by private subnets
- DNS hostnames and DNS support enabled

## Why The Wrapper Exists

The wrapper makes the repo-specific networking contract easy to reason about:

- public subnets are tagged for ALB placement
- private subnets are tagged for EKS workers and Karpenter discovery
- the cluster tag is applied consistently to both subnet types

That is the networking foundation for the repo's public-edge plus private-node
topology.
