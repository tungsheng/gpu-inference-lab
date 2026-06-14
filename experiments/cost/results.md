# Cost Per Useful Work Results

> Auditable evidence: the reports behind these tables are committed under
> `evidence/`. Replay them without a cluster with
> `./scripts/experiment replay --experiment cost`.

Curated live-cluster run: 2026-05-15 UTC, one serving GPU, cost scope
`serving-gpu-only`, hourly serving cost `$0.526`.

## Result Matrix

| Case | Profile | Status | Successful | Dropped | Failed | p95 latency | p99 latency | SLO passed | Cost | Cost/1K successful | Cost/1M tokens | Avg GPU |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| `steady-cost-efficiency` | `naive-single` | complete | 413 | 2227 | 0 | 60.31s | 60.35s | false | $0.056984 | $0.137976 | $1.077936 | 87.0% |
| `steady-cost-efficiency` | `optimized-batched` | complete | 2670 | 0 | 0 | 1.61s | 1.62s | true | $0.052738 | $0.019752 | $0.154313 | 82.5% |
| `burst-cost-efficiency` | `naive-single` | failed | 227 | 2882 | 43 | 120.00s | 120.00s | false | $0.037259 | $0.164137 | $1.282317 | 86.5% |
| `burst-cost-efficiency` | `optimized-batched` | complete | 2570 | 677 | 0 | 10.91s | 11.07s | false | $0.032813 | $0.012768 | $0.099748 | n/a |

## Source Reports

- `docs/reports/experiment-cost-steady-cost-efficiency-naive-single-20260514-171552.json`
- `docs/reports/experiment-cost-steady-cost-efficiency-optimized-batched-20260514-172916.json`
- `docs/reports/experiment-cost-burst-cost-efficiency-naive-single-20260514-172403.json`
- `docs/reports/experiment-cost-burst-cost-efficiency-optimized-batched-20260514-173650.json`

## Interpretation

For steady traffic, the optimized batched profile is both cheaper and much more
useful: 2670 successful requests versus 413, no dropped work versus 2227
dropped iterations, and `$0.019752` per 1K successful requests versus
`$0.137976`. It is also the only steady case that passed the 2s p95 and 5s p99
SLO.

For burst traffic, batching still produced far more useful work per dollar, but
it did not satisfy the latency SLO. The optimized burst case delivered 2570
successful requests at `$0.012768` per 1K successful requests, while the naive
case failed with 227 successes, 43 failed requests, and a 120s tail.

Decision impact: keep batching enabled for small-request economics, but do not
read the burst result as SLO-safe. Burst SLO compliance still needs admission,
autoscaling, or a different capacity shape.

## Graphs

- [Cost efficiency](graphs/cost-efficiency.svg) compares cost per 1K successful
  requests with p95 latency for the naive and optimized profiles.

## Boundaries

- Costs include only the serving GPU cost modeled by the experiment. They do not
  include control plane, networking, storage, observability, idle platform cost,
  or operator time.
- Failed requests are excluded from the useful-work denominator.
- The optimized burst report did not capture queue or GPU rollups, so its cost
  conclusion is based on successful work, generated tokens, latency, and serving
  cost rather than DCGM utilization.
