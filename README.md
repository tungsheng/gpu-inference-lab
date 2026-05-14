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

See [Evidence](docs/evidence.md) for numbers, boundaries, and pending claims.

## Quick Start

Local checks do not require AWS:

```bash
./scripts/experiment list
./scripts/experiment validate
./test/run.sh
```

Measured runs require Terraform, AWS CLI, `kubectl`, `helm`, AWS credentials,
access to `us-west-2`, and a live cluster:

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
- [Evidence](docs/evidence.md): curated measured conclusions and gaps
- [Runbook](docs/runbook.md): commands for local checks, live runs, and teardown
- [Platform reference](docs/platform-reference.md): implementation details
- [Experiment catalog](docs/experiment-catalog.md): experiment contracts and status
- [Reports](docs/reports/README.md): generated report schema and artifact rules
- [Roadmap](docs/roadmap.md): remaining work

## Repository Map

| Path | Purpose |
| --- | --- |
| `infra/` | Terraform VPC, EKS, and Karpenter AWS prerequisites |
| `platform/` | Kubernetes manifests for serving, capacity, observability, and validation |
| `experiments/` | experiment definitions, cases, profiles, and curated results |
| `scripts/` | lifecycle, evaluation, and experiment commands |
| `test/` | shell tests for scripts and manifest contracts |

The active environment favors iteration over production hardening. Use
[Platform reference](docs/platform-reference.md) for production boundary notes.
