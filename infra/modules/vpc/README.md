# infra/modules/vpc

This module is a thin local wrapper around the official
`terraform-aws-modules/vpc/aws` module.

It keeps the repo's current interface stable while delegating the VPC, subnet,
route table, internet gateway, and NAT gateway implementation to the upstream
AWS VPC module.

Current behavior:

- one VPC
- explicit public and private subnet CIDRs
- one public and one private subnet per availability zone
- a single NAT gateway shared by private subnets
- EKS and Karpenter subnet tags applied through module inputs
