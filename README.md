# GPU Inference Lab

**gpu-inference-lab** is a hands-on AWS project for a production-style GPU
inference platform on Amazon EKS.

The repo currently proves two paths:

- `./scripts/verify` cold-starts the public inference edge from zero GPU nodes
- `./scripts/evaluate --profile zero-idle|warm-1` proves HPA-driven burst
  scale-out with metrics and report output

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
   +--> vLLM Deployment
   |      |
   |      +--> HPA on vllm_requests_running (evaluate path)
   |
   +--> Prometheus + Grafana + Prometheus Adapter
   |
   v
Karpenter GPU NodePool(s)

EKS cluster
   |
   +--> managed system nodes (m7i-flex.large)
   |
   +--> gpu-serving NodePool (zero-idle and warm-1 baseline)
   |
   +--> gpu-warm-placeholder Deployment (warm-1 profile)
```

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable Terraform modules
- `platform/karpenter/`: GPU `EC2NodeClass` and `NodePool` manifests
- `platform/inference/`: vLLM deployment, HPA, public service, and ingress
- `platform/observability/`: Prometheus, Grafana, Prometheus Adapter, DCGM exporter, and dashboards
- `platform/tests/`: GPU smoke and burst-load manifests
- `scripts/`: lifecycle commands and the shared helper
- `docs/`: workflow, architecture, scaling, networking, and roadmap notes

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

Smoke-test the cold-start path:

```bash
./scripts/verify
```

Run the load-aware evaluation:

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
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
- Prometheus, Grafana, Prometheus Adapter, dashboards, and GPU metrics exporters
- Karpenter controller and CRDs
- GPU `EC2NodeClass` and `NodePool`
- NVIDIA device plugin
- `app` namespace
- public inference service and ingress

After `./scripts/up`, the cluster is ready for GPU work, the custom metrics API
is available for the HPA, and the default GPU node count should still be `0`.

## What `verify` Proves

- the vLLM deployment can trigger GPU node provisioning
- the first inference replica becomes Ready
- the public `/v1/completions` edge returns a `200`
- deleting the workload returns the cluster to zero GPU nodes

## What `evaluate` Proves

- `vllm_requests_running` can drive HPA scale-out from one to two replicas
- replica scale-out causes Karpenter to add a second GPU node
- Prometheus and DCGM metrics can answer latency, queue depth, and GPU saturation questions
- the repo can compare a zero-idle profile against a one-warm-node profile and write reports under `docs/reports/`

## Dev vs Production Access

The dev environment keeps the EKS API public for simplicity:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

That is a **dev-only convenience**. A production variant should switch to:

- private endpoint access
- bastion, SSM, or VPN-based admin access
- tighter CIDR controls for any remaining public exposure

## Docs

Start here:

- [Dev environment workflow](docs/dev-environment.md)
- [Operations](docs/operations.md)

Understand the platform:

- [Architecture](docs/architecture.md)
- [Inference](docs/inference.md)
- [Scaling](docs/scaling.md)
- [Cost optimization](docs/cost-optimization.md)
- [Networking](docs/networking.md)

Background and next steps:

- [Dynamic GPU serving](docs/dynamic-gpu-serving.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Roadmap](docs/roadmap.md)
