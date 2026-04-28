# GPU Inference Lab

GPU Inference Lab is a hands-on AWS EKS project for learning how an elastic GPU
inference platform behaves under cold start, burst load, and mixed-capacity
serving pressure.

The repo proves two real operator paths today:

- `./scripts/verify` cold-starts the public inference edge from zero GPU nodes
  and returns the cluster to zero GPU nodes after cleanup.
- `./scripts/evaluate --profile zero-idle|warm-1 --policy running|active-pressure|compare|sweep`
  applies vLLM plus the selected HPA policy, or sweeps multiple active-pressure
  targets, runs burst load, captures latency and utilization signals, and
  writes Markdown and JSON reports under `docs/reports/`.
- `./scripts/experiment` catalogs ML-serving experiments and renders
  experiment-specific load manifests, serving manifests, and report scaffolds
  without requiring a live cluster.

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
   +--> Prometheus / Grafana / Prometheus Adapter / Pushgateway
   |
   v
Karpenter-managed GPU nodes
   |
   +--> gpu-serving-ondemand
   +--> gpu-serving-spot

EKS cluster
   |
   +--> managed system nodes (m7i-flex.large)
   +--> no managed GPU node group
```

## Current Stack

- Terraform-managed VPC and EKS dev environment in `infra/env/dev`
- Managed system node group for controllers and shared services
- Karpenter-owned GPU capacity only, with no fixed managed GPU node group
- Shared GPU `EC2NodeClass` plus `gpu-serving-ondemand` and `gpu-serving-spot`
  `NodePool`s
- Real vLLM serving with `vllm/vllm-openai:v0.9.0` and
  `Qwen/Qwen2.5-0.5B-Instruct`
- Public ALB-backed inference edge through Kubernetes `Ingress`
- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  Grafana dashboards
- A `warm-1` profile that keeps one on-demand serving node alive through the
  lightweight `gpu-warm-placeholder` deployment
- An experiment catalog under `experiments/` for KV-cache, long-context,
  prefill/decode timing, batching scheduler tradeoffs, request-pattern
  utilization, and future cost and failure-injection work

## Quick Start

### Local Repo Usage

These commands do not require AWS access or a live Kubernetes cluster:

```bash
./scripts/experiment list
./scripts/experiment show kv-cache
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-load.yaml
./scripts/experiment render-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --samples 5 \
  --output /tmp/prefill-heavy-stream.yaml
./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile long-context \
  --output /tmp/vllm-long-context.yaml
./scripts/experiment render-serving \
  --experiment batching \
  --profile constrained-scheduler \
  --output /tmp/vllm-batching-constrained.yaml
./scripts/experiment render-load \
  --experiment request-patterns \
  --case uneven-size-mix \
  --output /tmp/request-patterns-uneven-size-mix.yaml
./scripts/experiment render-report \
  --experiment kv-cache \
  --case prompt-8192-output-300 \
  --profile long-context
./test/run.sh
```

Use this path to inspect the experiment catalog, render reproducible workload
manifests, scaffold report artifacts, and validate the repo's shell surface
locally.

### Live AWS/EKS Usage

Prerequisites:

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- access to `us-west-2`

Bring the dev environment up:

```bash
./scripts/up
```

Prove the zero-GPU cold-start path:

```bash
./scripts/verify
```

Run controlled burst evaluations:

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
./scripts/evaluate --profile zero-idle --resilience spot-unavailable
./scripts/evaluate --profile zero-idle --resilience spot-interruption
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8
```

Run a live experiment case:

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default
./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --profile default \
  --samples 5
./scripts/experiment run \
  --experiment batching \
  --case steady-512-output-128 \
  --profile dynamic-default
./scripts/experiment run \
  --experiment request-patterns \
  --case steady-small \
  --profile default
```

Tear everything down:

```bash
./scripts/down
# or, if a failed destroy leaves behind available aws-K8S ENIs:
./scripts/down --cleanup-orphan-enis
```

## What The Scripts Do

- `./scripts/up` applies Terraform, connects kubeconfig, installs the AWS Load
  Balancer Controller, observability stack, Karpenter, GPU prerequisites, and
  the public inference service plus ingress. It leaves GPU node count at `0`.
- `./scripts/verify` applies only the vLLM deployment, waits for one GPU node,
  one Ready replica, and one successful external completion, then deletes the
  workload and waits for GPU cleanup back to `0`.
- `./scripts/evaluate` applies the vLLM deployment, selects the running or
  active-pressure HPA policy, or sweeps multiple active-pressure targets, runs
  the checked-in burst load, waits for a second replica and second GPU node,
  collects Prometheus and DCGM metrics, estimates serving-node cost, and
  writes reports. Final metric collection is best-effort: if the Kubernetes API
  or Prometheus access fails after cleanup, the script still writes a partial
  report with timeline, cost, and resilience fields preserved. `--policy
  compare` runs the running baseline first and the
  active-pressure policy second, then writes a side-by-side compare report.
  `--policy sweep` runs one active-pressure experiment per target in
  `--active-targets` and writes a recommendation summary. `--resilience
  spot-unavailable` withdraws the preferred spot `NodePool` for the run,
  proves on-demand fallback behavior under burst load, and restores the spot
  pool afterward. `--resilience spot-interruption` temporarily withdraws the
  on-demand serving `NodePool` before the burst so the second node must land on
  spot, then restores on-demand, deletes the live spot-backed burst
  `NodeClaim`, forces on-demand recovery, and reports replacement timing.
- `./scripts/experiment` lists planned experiments, shows experiment cases,
  renders local Kubernetes manifests plus Markdown/JSON report scaffolds, and
  can run one live load or streaming case/profile at a time against a
  configured cluster. This is the front door for KV-cache, prefill/decode,
  batching scheduler tradeoffs, request-pattern utilization, and future cost,
  failure-injection, and multi-model experiments.
- `./scripts/down` removes runtime resources, observability, GPU capacity
  definitions, controllers, and Terraform-managed infrastructure. The optional
  `--cleanup-orphan-enis` flag retries one failed `terraform destroy` after
  deleting cleanup-eligible `available` `aws-K8S` / `aws-node` ENIs in the
  VPC.

## What The Evaluation Path Answers

- How long does the first GPU node take to appear from a zero-idle baseline?
- How long does the first public completion take to succeed?
- How do the running-request and active-pressure HPAs compare under the same
  burst profile?
- Which active-pressure target best balances queue pressure, latency, GPU
  utilization, and burst cost for this pod-per-GPU shape?
- Does replica growth trigger a second Karpenter `NodeClaim` and second GPU
  node?
- What do p95 request latency, p95 estimated queue wait, p95 time to first
  token, peak waiting requests, peak active requests, token throughput, and GPU
  utilization look like during a controlled burst?
- What is the tradeoff between `zero-idle` and `warm-1` for latency and serving
  cost?
- What happens when the preferred spot burst path is unavailable and the burst
  has to fall back to on-demand GPU capacity?
- What happens when a live spot-backed burst node disappears mid-burst, and how
  long does replacement take?

## Current Autoscaling Story

The repo now ships with two HPA policies:

- `running`: the original baseline that scales from `vllm_requests_running`
- `active-pressure`: the new capacity-aware policy that scales from
  `vllm_requests_active = waiting + running`

`./scripts/evaluate --policy compare` runs both sequentially and
`./scripts/evaluate --policy sweep --active-targets ...` calibrates multiple
active-pressure targets in one pass. The remaining gap is no longer "can this
scale?" but "is the target calibrated from the right queue and per-GPU
capacity signals?" Queue reporting now derives a p95 queue-wait estimate from
waiting depth over request completion rate, and the repo now also covers both
pre-run spot scarcity and a live interruption drill through
`--resilience spot-unavailable` and `--resilience spot-interruption`.

## Dev Boundary

The active environment is intentionally dev-oriented:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

That is a convenience for fast iteration, not the target production posture. A
production variant should move to private cluster access plus SSM, bastion, or
VPN-based administration and tighter public CIDR controls.

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable VPC, EKS, and Karpenter Terraform modules
- `platform/inference/`: vLLM deployment, service, ingress, and HPA manifests
- `platform/karpenter/`: GPU `EC2NodeClass` and `NodePool` manifests
- `platform/observability/`: Prometheus, Grafana, adapter, exporter, and
  dashboard assets
- `platform/tests/`: manual GPU smoke test, load generator, and warm placeholder
- `platform/system/`: cluster-level runtime prerequisites such as the NVIDIA
  device plugin
- `experiments/`: repeatable experiment definitions, workload cases, serving
  profiles, result narratives, and graph placeholders
- `scripts/`: lifecycle commands and shared shell helpers
- `docs/`: repo-level architecture, workflow, scaling, networking, and roadmap
  documentation

## Documentation

Start here:

- [Dev environment workflow](docs/dev-environment.md)
- [Operations](docs/operations.md)
- [Experiment platform plan](docs/experiment-platform-plan.md)
- [Experiments summary](docs/experiments-summary.md)

Platform deep dives:

- [Architecture](docs/architecture.md)
- [Inference](docs/inference.md)
- [Scaling](docs/scaling.md)
- [Cost optimization](docs/cost-optimization.md)
- [Networking](docs/networking.md)

Background and next steps:

- [Dynamic GPU serving](docs/dynamic-gpu-serving.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Roadmap](docs/roadmap.md)
