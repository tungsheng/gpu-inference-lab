# GPU Inference Lab

GPU Inference Lab is a hands-on AWS EKS project for learning how an elastic GPU
inference platform behaves under cold start, burst load, mixed-capacity serving,
and operator-visible cost signals.

The repo has three main workflows:

- `./scripts/verify` proves the public inference path from zero GPU nodes.
- `./scripts/evaluate` runs controlled burst evaluations and writes reports.
- `./scripts/experiment` validates and runs focused ML-serving experiments.

## Platform At A Glance

```text
Internet
   |
   v
AWS Application Load Balancer
   |
   v
Ingress (/v1)
   |
   v
ClusterIP Service
   |
   v
vLLM Deployment
   |
   +--> HPA on vllm_requests_running or vllm_requests_active
   |
   +--> Prometheus / Grafana / Prometheus Adapter / Pushgateway / DCGM
   |
   v
Karpenter-managed GPU nodes
   |
   +--> gpu-serving-ondemand
   +--> gpu-serving-spot

EKS cluster
   |
   +--> managed system nodes
   +--> no managed GPU node group
```

## Current Stack

- Terraform-managed VPC and EKS dev environment in `infra/env/dev`
- managed system node group for controllers and shared services
- Karpenter-owned GPU capacity with separate on-demand and spot serving pools
- real vLLM serving with `vllm/vllm-openai:v0.9.0` and
  `Qwen/Qwen2.5-0.5B-Instruct`
- public ALB-backed `/v1` inference edge
- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  dashboards
- `zero-idle` and `warm-1` evaluation profiles
- experiment catalog for KV cache, prefill/decode, batching, request patterns,
  autoscaling, and cost-per-useful-work questions

## Quick Start

Local catalog checks and render-only commands do not require AWS access. These
commands validate experiment definitions and generate manifests or empty report
scaffolds; they do not run workloads or produce measured results.

```bash
./scripts/experiment list
./scripts/experiment validate
./scripts/experiment show kv-cache
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-load.yaml
./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile long-context \
  --output /tmp/vllm-long-context.yaml
./scripts/experiment render-report \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
./test/run.sh
```

Measured validation and experiment runs require Terraform, AWS CLI, `kubectl`,
`helm`, AWS credentials, access to `us-west-2`, and a live cluster from
`./scripts/up`:

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default
./scripts/down
```

Use `./scripts/down --cleanup-orphan-enis` only when `terraform destroy` fails
because cleanup-eligible `aws-K8S` or `aws-node` ENIs remain in the VPC.
Use `./scripts/down --terraform-only` only after Kubernetes cleanup has already
finished or the cluster API is no longer reachable.

## Documentation

Start here:

- [Operations](docs/operations.md): choose the right command and read results
- [Dev environment workflow](docs/dev-environment.md): full setup, validation,
  and teardown runbook
- [Architecture](docs/architecture.md): platform shape and control loops
- [Experiments summary](docs/experiments-summary.md): experiment catalog and
  current status
- [Reports](docs/reports/README.md): generated report format and artifact rules

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable VPC, EKS, and Karpenter Terraform modules
- `platform/inference/`: vLLM deployment, service, ingress, and HPA manifests
- `platform/karpenter/`: active GPU `EC2NodeClass` and `NodePool` manifests
- `platform/observability/`: metrics, dashboards, adapter, exporter, and
  Pushgateway assets
- `platform/system/`: runtime prerequisites such as the NVIDIA device plugin
- `platform/workloads/validation/`: smoke, load, and warm-placeholder workloads
- `experiments/`: experiment definitions, cases, serving profiles, and results
- `scripts/`: lifecycle and experiment commands
- `test/`: shell tests for the public script and manifest contract

## Dev Boundary

The active environment is optimized for iteration, not production hardening:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

A production variant should use private cluster access, a documented operator
access path such as SSM, bastion, or VPN, and narrower public CIDR controls.
