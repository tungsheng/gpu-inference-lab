# gpu-inference-lab Roadmap

## Project Objective

Build a production-style GPU inference platform on AWS using:

- Terraform
- Amazon EKS
- Karpenter
- Application Load Balancer
- GPU model serving infrastructure

The platform should demonstrate real ML infrastructure patterns instead of a toy autoscaling demo.

## Target Architecture

Final system:

```text
                 Internet
                    |
                    v
     ALB (Application Load Balancer)
                    |
                    v
              Kubernetes Ingress
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
            /               \
           /                 \
    Spot GPU Nodes      On-Demand GPU Nodes
```

## Repository Structure

Target structure:

```text
gpu-inference-lab/

infra/
  modules/
    vpc/
    eks/
    alb-controller/
    karpenter/

  envs/
    dev/

platform/
  ingress/
  karpenter/
  inference/

docs/
  roadmap.md
  architecture.md
  networking.md
  scaling.md
  inference.md
  operations.md
```

Current repository notes:

- The live Terraform environment path is `infra/env/dev`.
- The AWS Load Balancer Controller manifests currently live under `platform/controller/aws-load-balancer-controller`.
- The sample public workload currently lives under `platform/test-app`.

Keep the target structure in mind for new work, but do not break the current apply and destroy flow while migrating paths.

## Milestone 0 - Repository Foundation

Status: implemented.

Objective:

- Create a maintainable repository layout and initial documentation.

Deliverables:

- Terraform modules directory
- Environment configuration
- Documentation skeleton

Documentation:

- `docs/architecture.md`
- `docs/roadmap.md`

## Milestone 1 - AWS Networking Layer

Status: implemented.

Objective:

- Deploy production-style VPC networking.

Infrastructure:

- VPC
- Public subnets
- Private subnets
- Internet Gateway
- NAT Gateway
- Route tables

Deliverables:

- `infra/modules/vpc/`

Documentation:

- `docs/networking.md`

## Milestone 2 - EKS Cluster Deployment

Status: implemented.

Objective:

- Deploy the Kubernetes cluster.

Infrastructure:

- EKS control plane
- Managed node group
- IAM roles
- OIDC provider

Deliverables:

- `infra/modules/eks/`

Verification:

- `kubectl get nodes`
- Expected result: nodes are `Ready`

Documentation:

- `docs/architecture.md`

## Milestone 3 - Ingress and Load Balancer

Status: implemented.

Objective:

- Expose workloads externally.

Components:

- AWS Load Balancer Controller
- Kubernetes ingress
- Application Load Balancer

Deliverables:

- `platform/controller/`
- `platform/test-app/`

Documentation:

- `docs/networking.md`

## Milestone 4 - Dynamic Compute Layer

Status: next.

Objective:

- Introduce node autoscaling with Karpenter.

Components:

- Karpenter controller
- `EC2NodeClass`
- `NodePool`

Demonstration:

- No GPU nodes exist initially
- A GPU pod is created
- A node is launched
- The pod is scheduled

Deliverables:

- `infra/modules/karpenter/`
- `platform/karpenter/`

Documentation:

- `docs/scaling.md`

## Milestone 5 - GPU Scheduling

Status: planned.

Objective:

- Enable GPU workloads.

Add:

- GPU node pools
- Taints
- Tolerations
- GPU resource requests such as `nvidia.com/gpu: 1`

Documentation:

- `docs/scaling.md`

## Milestone 6 - Heterogeneous GPU Fleet

Status: planned.

Objective:

- Allow multiple GPU instance types in the same provisioning strategy.

Example instance families:

- `g5.xlarge`
- `g5.2xlarge`
- `g5.4xlarge`
- `g5.12xlarge`

Why:

- Capacity availability
- Cheaper instance selection
- Faster scheduling

Documentation:

- `docs/scaling.md`

## Milestone 7 - Spot and On-Demand GPU Strategy

Status: planned.

Objective:

- Reduce GPU cost while keeping fallback capacity.

Node pools:

- `gpu-spot`
- `gpu-ondemand`

Documentation:

- `docs/cost-optimization.md`

## Milestone 8 - AZ Distribution

Status: planned.

Objective:

- Prevent GPU shortages by distributing capacity across availability zones.

Key selector:

- `topology.kubernetes.io/zone`

Documentation:

- `docs/scaling.md`

## Milestone 9 - GPU Bin Packing

Status: planned.

Objective:

- Improve GPU utilization.

Desired outcome:

- Pack multiple inference workers efficiently onto larger GPU nodes when that is the cost-effective placement.

Documentation:

- `docs/gpu-binpacking.md`

## Milestone 10 - Warm GPU Pools

Status: planned.

Objective:

- Reduce inference cold-start latency.

Problem:

- GPU node launch time can take several minutes.

Solution:

- Maintain a small minimum GPU pool for faster first-request latency.

Documentation:

- `docs/scaling.md`

## Milestone 11 - Inference Service

Status: planned.

Objective:

- Deploy a real ML inference service.

Candidate runtimes:

- vLLM
- Triton
- TorchServe

Deliverables:

- `platform/inference/`

Documentation:

- `docs/inference.md`

## Milestone 12 - Autoscaling Inference

Status: planned.

Objective:

- Autoscale the inference workload itself.

Add:

- Horizontal Pod Autoscaler
- Queue or latency-driven metrics

Documentation:

- `docs/scaling.md`

## Milestone 13 - Observability

Status: planned.

Objective:

- Monitor the inference platform.

Add:

- Prometheus
- Grafana
- GPU metrics

Documentation:

- `docs/operations.md`

## Milestone 14 - Production Hardening

Status: planned.

Objective:

- Add the operational controls expected in a production-style platform.

Add:

- Rate limiting
- Health checks
- PodDisruptionBudget
- Security policies

Documentation:

- `docs/operations.md`

## Final Outcome

The finished project should demonstrate:

- Cloud networking
- Kubernetes scheduling
- GPU autoscaling
- Spot cost optimization
- Model serving
- Cluster observability
