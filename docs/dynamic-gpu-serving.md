# Dynamic GPU Serving

This document captures the milestone the repo has already reached: GPU serving
is no longer a static manifest exercise. It is a scripted, measurable, and
publicly reachable serving workflow.

## What Is Proven

The project now proves all of the following in one repo:

- a public inference edge through ALB plus Kubernetes ingress
- a real vLLM deployment instead of a placeholder GPU pod
- Karpenter-owned GPU capacity with no managed GPU node group
- observability and custom metrics in the default scripted path
- two experiment profiles: `zero-idle` and `warm-1`
- two autoscaling policies plus a compare workflow

That makes the repository a credible ML platform lab rather than only a cluster
bootstrap demo.

## Why This Milestone Matters

The important improvement is not just that GPU nodes launch. It is that the
repo can now answer operational questions:

- can the first public request succeed from a zero-GPU baseline?
- can burst traffic drive replica scale-out?
- does scale-out trigger a second GPU node?
- what do latency, throughput, and GPU utilization look like during the burst?
- what is the latency-versus-idle-cost tradeoff of keeping one warm GPU node?

## Where The Pieces Live

- `platform/inference/`: vLLM deployment, service, ingress, and HPA
- `platform/karpenter/`: shared GPU node class and serving `NodePool`s
- `platform/observability/`: Prometheus, Grafana, adapter, dashboards,
  Pushgateway, and GPU exporters
- `platform/tests/`: load generator, warm placeholder, and manual GPU smoke
  manifest
- `scripts/verify`: cold-start validation path
- `scripts/evaluate`: burst evaluation and report generation path

## What The Current Proof Chain Looks Like

Success for the dynamic serving path looks like:

- one pending vLLM pod triggers Karpenter capacity
- one GPU node joins and exposes `nvidia.com/gpu`
- one vLLM replica becomes Ready
- the public `/v1/completions` path returns `200`
- the HPA raises desired replicas to `2`
- a second serving `NodeClaim` and second GPU node appear
- the second replica becomes Ready
- the report captures timing, latency, utilization, and cost

## What Is Still Missing

The repo now has the capacity-aware signal, so the missing piece is no longer
"can the HPA see pressure?" It is "how much useful work should one GPU-backed
pod absorb before scaling?" The next milestone is GPU bin packing and
per-request efficiency, not more AWS surface area.
