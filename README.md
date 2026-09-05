# GPU Inference Lab

GPU Inference Lab turns real serving measurements into inference architecture
decisions.

It runs an AWS EKS and vLLM platform to measure GPU warm capacity, admission
control, autoscaling signals, context-length limits, scheduler shape, and
quantization tradeoffs.

## What It Answers

| Question | Primary evidence |
| --- | --- |
| Zero-idle, warm baseline, or always-on serving? | burst evaluations and autoscaling results |
| Running-request HPA or active-pressure HPA? | compare and sweep reports |
| Direct traffic or bounded admission? | autoscaling direct vs queued cases |
| Safe context length, rate, and concurrency? | KV-cache sweeps |
| Scheduler, KV-cache, or quantization change? | experiment matrices |
| Spot, on-demand, or specialized GPU capacity? | Karpenter capacity profiles and resilience drills |

## Proven So Far

Current evidence shows:

- scale-from-zero is dominated by container/image/model readiness, not by GPU
  node creation
- bounded admission protects delivery ratio and p95 latency during bursts, with
  lower completed volume in the same wall-clock window
- the `8192/300` long-context profile has a visible saturation knee, and
  FP8 KV cache regresses that workload on the current g4dn/vLLM `v0.9.0` path
- active admission at the long-context knee cuts tail latency by turning excess
  demand into explicit backpressure
- for `512/128` steady and burst traffic, vLLM dynamic scheduler defaults beat
  the tested explicit sequence and batched-token caps
- request shape matters: steady traffic stayed clean, while burst and
  spike-to-zero traffic converted excess direct-client demand into dropped work
- optimized batching sharply reduces cost per useful request, but burst traffic
  still needs admission, autoscaling, or more capacity to meet latency SLOs
- active-pressure HPA is measurable end to end; the latest zero-idle sweep
  recommends target `8` only as the highest underutilized tested target
- streamed workloads need separate TTFT, inter-token, and total-latency budgets

See [Recommendations](docs/recommendations.md) for the current architecture
readout and [Evidence](docs/evidence.md) for numbers, boundaries, and pending
claims.

## Quick Start

Local checks do not require AWS:

```bash
./scripts/experiment list
./scripts/experiment validate
./scripts/experiment replay --experiment kv-cache-observatory
./test/run.sh
```

`replay` renders the committed evidence behind a curated `results.md` table from
checked-in JSON, so the measured conclusions are auditable without a cluster.

`validate` also checks the checked-in serving images against
`platform/inference/versions.env` and every committed evidence file against
`schemas/`.

Measured runs require Terraform, AWS CLI, `kubectl`, `helm`, AWS credentials,
access to `us-west-2`, and a live cluster. The inference ALB is restricted to
the public IP of the machine running the command unless you set
`GPU_INFERENCE_INBOUND_CIDRS`:

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default
./scripts/down
```

Use [Runbook](docs/runbook.md) for render commands, live-run variants, manual
checks, and teardown recovery.

## Documentation

- [Decision engine](docs/decision-engine.md): measurement-to-architecture flow
- [Recommendations](docs/recommendations.md): current supported, partial, and rejected choices
- [Evidence](docs/evidence.md): curated measured conclusions and gaps
- [Runbook](docs/runbook.md): commands for local checks, live runs, and teardown
- [Platform reference](docs/platform-reference.md): implementation details
- [Experiment catalog](docs/experiment-catalog.md): experiment contracts and status
- [Reports](docs/reports/README.md): generated report schema and artifact rules
- [Roadmap](docs/roadmap.md): remaining work

## Repository Map

| Path | Purpose |
| --- | --- |
| `infra/` | Terraform VPC, EKS, and Karpenter AWS prerequisites, plus remote-state bootstrap |
| `platform/` | Kubernetes manifests for serving, capacity, observability, and validation |
| `experiments/` | experiment definitions, cases, profiles, and curated results |
| `scripts/` | lifecycle, evaluation, and experiment commands |
| `schemas/` | JSON Schemas every report and seam document is checked against |
| `observatory/` | KV-cache trace collection and visualization helpers |
| `test/` | shell tests for scripts and manifest contracts |

Failure drills use the same catalog/reporting style:

```bash
./scripts/failure list
./scripts/failure run --scenario spot-interruption --mitigation ondemand-fallback --dry-run
./scripts/failure matrix --suite capacity-recovery --dry-run
```

The active environment favors iteration over production hardening. Use
[Platform reference](docs/platform-reference.md) for production boundary notes.
