# GPU Inference Lab

**gpu-inference-lab** is a hands-on AWS project for a production-style GPU
inference platform on Amazon EKS.

The default workflow is intentionally small:

- `./scripts/up` provisions AWS infrastructure and installs the minimum
  Kubernetes platform pieces needed for the public inference path
- `./scripts/verify` proves the cold-start path end to end by waiting for a GPU
  node, a Ready vLLM pod, one successful public response, and a return to zero
  GPU nodes
- `./scripts/down` tears the platform down in reverse order and then destroys
  the Terraform environment

## Architecture At A Glance

```text
Internet
   |
   v
ALB
   |
   v
Ingress (/v1)
   |
   v
vLLM Service
   |
   v
vLLM Pod on Karpenter GPU Node

EKS cluster
   |
   +--> managed system nodes (m7i-flex.large)
   |
   +--> Karpenter GPU NodePool (g4dn.xlarge / g5.xlarge)
          |
          +--> workload=gpu
          +--> gpu=true:NoSchedule
          +--> NVIDIA device plugin
```

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable Terraform modules
- `platform/karpenter/`: GPU `EC2NodeClass`, `NodePool`, and service account
- `platform/inference/`: vLLM deployment, public service, ingress, and optional HPA
- `platform/system/`: cluster-level runtime manifests such as the NVIDIA device plugin
- `platform/tests/`: optional manual validation manifests
- `scripts/`: the minimal lifecycle commands and shared helper
- `docs/`: workflow, architecture, scaling, inference, and roadmap notes

## Prerequisites

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- region set up for `us-west-2`

## Quick Start

Bring the environment up:

```bash
./scripts/up
```

Validate the public inference path:

```bash
./scripts/verify
```

Tear the environment down:

```bash
./scripts/down
```

Run the local shell checks:

```bash
./test/run.sh
```

## What `up` Installs

- Terraform-managed VPC, EKS cluster, and IAM roles
- AWS Load Balancer Controller
- Karpenter controller and CRDs
- GPU `EC2NodeClass` and `NodePool`
- NVIDIA device plugin
- `app` namespace
- public inference service and ingress

After `./scripts/up`, the cluster is ready for GPU work, but the default GPU
node count should still be `0`.

## What `verify` Proves

- the vLLM deployment can trigger GPU node provisioning
- the first inference replica becomes Ready
- the public `/v1/completions` edge returns a `200`
- deleting the workload returns the cluster to zero GPU nodes

## Advanced And Manual Extensions

These assets stay in the repo, but they are not part of the default scripted
workflow:

- `platform/inference/hpa.yaml` for queue-depth-driven autoscaling
- `platform/observability/` for Prometheus, Grafana, and related dashboards
- `platform/tests/` for manual smoke and load-test manifests

## Docs

- [Architecture](docs/architecture.md)
- [Dev environment workflow](docs/dev-environment.md)
- [Dynamic GPU serving](docs/dynamic-gpu-serving.md)
- [Operations](docs/operations.md)
- [Scaling](docs/scaling.md)
- [Inference](docs/inference.md)
- [Cost optimization](docs/cost-optimization.md)
- [Networking](docs/networking.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Roadmap](docs/roadmap.md)
