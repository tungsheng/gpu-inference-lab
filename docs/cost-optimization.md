# Cost Optimization

The lab focuses on serving GPU cost, not full AWS billing reconciliation.

## Main Tradeoff

| Profile | Idle GPU cost | First-response latency | Best fit |
| --- | --- | --- | --- |
| `zero-idle` | lowest | highest | sparse traffic and aggressive cost control |
| `warm-1` | higher | lower | frequent bursts where first response matters |

Run both profiles through `./scripts/evaluate` when you want to compare latency,
scale-out timing, and estimated serving-node cost.

## Mixed Capacity

The active serving path uses two GPU pools:

- `gpu-serving-spot`: preferred fresh burst capacity
- `gpu-serving-ondemand`: fallback path and warm baseline anchor

`warm-1` intentionally keeps the baseline on on-demand capacity so the idle
anchor is predictable.

## Report Scope

Evaluation reports estimate serving GPU cost only. They exclude:

- EKS control plane cost
- managed system node cost
- NAT Gateway and ALB cost
- storage and data transfer
- price drift beyond the fixed table in `scripts/evaluate`

That narrow scope makes reports useful for relative serving experiments, not
exact cloud bill reconciliation.

## Experiment Path

The cost experiment compares useful work per serving GPU:

```bash
./scripts/experiment run \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

Compare `naive-single` and `optimized-batched` with the same case. Read cost per
successful request and cost per generated token beside p95/p99 latency,
failures, and SLO pass/fail.
