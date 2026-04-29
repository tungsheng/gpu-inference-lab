# Roadmap

## Current State

The lab currently proves a dev-oriented GPU inference platform on AWS:

- Terraform creates the VPC, EKS control plane, and managed system node group.
- `./scripts/up` installs the public edge, observability, Karpenter, GPU
  runtime prerequisites, and serving capacity definitions.
- `./scripts/verify` cold-starts a real vLLM workload from zero GPU nodes and
  cleans back down to zero.
- `./scripts/evaluate` drives burst traffic, compares HPA signals, sweeps
  active-pressure targets, records synthetic resilience drills, and writes
  Markdown/JSON reports.
- `./scripts/experiment` validates local experiment definitions and can run one
  focused live experiment case at a time.

Implemented platform capabilities:

- public ALB-backed `/v1` inference edge
- Karpenter-managed GPU capacity with no managed GPU node group
- separate on-demand and spot serving `NodePool`s
- `zero-idle` and `warm-1` evaluation profiles
- vLLM serving with `Qwen/Qwen2.5-0.5B-Instruct`
- Prometheus, Grafana, Prometheus Adapter, Pushgateway, DCGM exporter, and
  dashboards
- running-request and active-pressure HPA policies
- compare and sweep report generation
- pre-run spot scarcity and synthetic spot interruption evaluation modes

## Known Limits

- The environment is dev-oriented and keeps the EKS API public.
- Queue wait is derived from waiting depth over completion rate, not a
  dedicated queue-wait histogram.
- Active-pressure target recommendations are heuristic.
- GPU efficiency is measured for the current one-pod-per-GPU shape, but the
  repo does not yet compare multiple packing shapes or node sizes.
- Spot interruption testing deletes a live `NodeClaim`; it does not consume
  cloud-native interruption notices.
- Experiment result summaries are scaffolded, but curated production run
  conclusions have not been recorded.

## Next Work

### Production Hardening

Goal: make the platform posture match production expectations rather than demo
convenience.

Completion should include:

- private EKS endpoint access
- SSM, bastion, or VPN-based operator access
- narrower public CIDR controls
- clearer guidance for secrets, credentials, and public inference exposure
- documented destroy and recovery procedures for shared accounts

### Queue And Saturation Precision

Goal: improve autoscaling and report quality with more direct serving signals.

Completion should include:

- a dedicated queue-wait metric or histogram if vLLM/exporter support allows it
- clearer separation between queueing delay, model prefill, decode time, and
  downstream client timeout behavior
- sweep recommendations based on measured saturation thresholds rather than
  simple guardrails

### GPU Efficiency And Packing

Goal: compare useful work per GPU across serving and capacity shapes.

Completion should include:

- experiments that compare current one-pod-per-GPU behavior with alternative
  scheduler settings, node sizes, or placement strategies
- cost per useful request and generated token read beside latency and failure
  rates
- dashboard and report language that explains stranded capacity clearly

### Experiment Publishing

Goal: turn generated reports into curated project evidence.

Completion should include:

- selected checked-in JSON report data for representative runs
- charts generated from report data
- concise `experiments/<name>/results.md` conclusions
- a maintained cross-experiment summary in `docs/experiments-summary.md`

## Completed History

The main completed milestones are:

- repository foundation and shell test surface
- AWS networking and EKS system plane
- public inference edge
- dynamic GPU capacity through Karpenter
- NVIDIA device plugin and GPU scheduling rules
- real vLLM serving and deployment-only cold-start validation
- observability-driven evaluation
- mixed on-demand/spot serving profiles
- active-pressure autoscaling and compare reports
- active-target sweep reports
- synthetic degraded-capacity and interruption drills
