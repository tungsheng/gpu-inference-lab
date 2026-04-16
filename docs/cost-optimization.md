# Cost Optimization

## Cost Posture Today

The repo is built around a zero-idle default:

- system nodes stay up all the time
- serving GPU nodes appear only when a workload requests `nvidia.com/gpu`
- empty GPU nodes are eligible for Karpenter consolidation

That keeps idle GPU spend low, but it pushes first-request latency into the
user experience.

## The Main Tradeoff

The scripted evaluation compares two practical postures:

| Profile | Idle GPU cost | First-response latency | When it makes sense |
| --- | --- | --- | --- |
| `zero-idle` | lowest | highest | sparse traffic, aggressive cost control |
| `warm-1` | higher | lower | frequent bursts, faster first response matters |

Run both with:

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
```

## Mixed Capacity Story

The serving path is no longer all on-demand:

- `gpu-serving-spot` is the preferred path for fresh burst capacity
- `gpu-serving-ondemand` remains available for the warm baseline and fallback
- `warm-1` intentionally keeps the baseline on on-demand capacity so the idle
  anchor is stable

That is the right framing for an ML serving lab: cost and latency are tied to
both how many nodes you keep warm and what capacity type you use when bursts
arrive.

## What The Reports Measure

Each evaluation report includes:

- first and second GPU node timing
- first and second GPU capacity type
- first response timing
- HPA scale-out timing
- p95 request latency and p95 time to first token
- generation throughput
- average and max GPU utilization
- peak active serving `NodeClaim` count, split by capacity type
- estimated idle cost per hour for the profile
- estimated burst cost for the run, split by capacity type

## What The Cost Estimate Actually Covers

The estimate is intentionally narrow and deterministic:

- it covers serving GPU node cost only
- it uses a fixed conservative hourly price table in `scripts/evaluate`
- it splits values by on-demand versus spot when capacity types differ

It does **not** attempt to model the full AWS bill. It excludes:

- EKS control plane cost
- system node cost
- NAT Gateway and ALB cost
- storage and data transfer
- any pricing drift beyond the fixed table in the script

That makes the reports useful for relative serving experiments, not for exact
cloud billing reconciliation.

## How To Read Results

Prefer `zero-idle` when:

- traffic is sparse
- cold-start latency is acceptable
- the main goal is minimizing idle GPU spend

Prefer `warm-1` when:

- cold-start latency is painful
- bursts are frequent enough that one warm GPU node is justified
- you want a stable on-demand baseline and can tolerate the idle cost

## What Comes Next

The next cost optimization step is not another pricing table. It is a better
capacity signal. Once autoscaling is based on active pressure rather than only
running requests, the repo will be able to reason about cost per useful unit of
work instead of cost per launched GPU node.
