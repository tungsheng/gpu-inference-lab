# Evidence

Curated cross-experiment readout: what the repository supports, what remains a
hypothesis, and where the source details live.

Generated artifacts under `docs/reports/` are ignored by default. Stable
experiment conclusions belong in `experiments/<name>/results.md`; this page
connects them to decisions.

## Supported Conclusions

### Autoscaling And Admission

Source: `experiments/autoscaling/results.md`

The scale-from-zero path is dominated by container/image/model readiness, not by
Karpenter node creation. In the measured spike runs:

| Case | First NodeClaim | First GPU node | Pod scheduled | Container started | Model ready |
| --- | ---: | ---: | ---: | ---: | ---: |
| `spike-direct` | 3s | 35s | 65s | 354s | 425s |
| `spike-queued` | 12s | 35s | 65s | 357s | 439s |

Direct open-loop clients completed more requests in the same run window but
shed work and had much higher tail latency. Bounded queued clients protected
delivery ratio and p95 latency by limiting active concurrency.

| Case | Successful | Dropped | Delivery ratio | p95 latency | Requests/sec | Peak active |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `burst-direct` | 2632 | 787 | 0.769816 | 14.62s | 15.95 | 255 |
| `burst-queued` | 1656 | 0 | 1.000000 | 2.19s | 10.03 | 24 |
| `spike-direct` | 1762 | 237 | 0.881441 | 14.23s | 15.89 | 254 |
| `spike-queued` | 1063 | 0 | 1.000000 | 1.98s | 9.61 | 20 |

Decision impact: when traffic can arrive before capacity and model readiness
catch up, bounded admission belongs in the architecture.

### KV Cache And Long Context

Source: `experiments/kv-cache/results.md`

The `8192/300` long-context sweep has a measured saturation knee on the current
single-replica, one-GPU `long-context` profile:

| Target rate | Outcome | Signal |
| ---: | --- | --- |
| `1.00 req/s` | stable | p95 `11.92s`, peak active `12`, GPU max `100%` |
| `1.10 req/s` | stable but tail rising | p95 `21.67s`, peak active `24` |
| `1.15 req/s` | queueing begins | p95 `35.35s`, peak waiting `8`, active `40` |
| `1.20 req/s` | practical edge | p95 `54.35s`, peak waiting `30`, active `62` |
| `1.25 req/s` | saturation begins | p95 `93.78s`, peak waiting `72`, active `104` |
| `1.50 req/s` | overloaded | p95 `180.27s`, dropped/interrupted backlog |

Decision impact: long-context serving needs a concurrency and admission
boundary. A profile can have zero request failures and still miss the SLO
because queueing and tail latency explode.

### FP8 KV Cache On Current g4dn Path

Source: `experiments/kv-cache/results.md`

The FP8 KV variants on the current one-GPU g4dn/vLLM `v0.9.0` path did not pass
the "stable stays stable" gate for the `8192/300` workload:

| Profile | Delivery ratio | p95 latency | Generated tokens/sec | Outcome |
| --- | ---: | ---: | ---: | --- |
| `long-context` | 1.000000 | 11.92s | 249.58 | stable |
| `long-context-fp8-kv` | 0.691152 | 245.29s | 165.60 | regressed |
| `long-context-fp8-kv-static-scales` | 0.475793 | 300.00s | 114.00 | worse |
| `long-context-fp8-kv-seqs-12` | 0.671119 | 253.00s | 160.80 | still regressed |

Decision impact: do not select FP8 KV for this hardware/software path unless a
newer vLLM image or different GPU backend is under test.

## Partial Or Pending Evidence

| Area | State | Recommendation needs |
| --- | --- | --- |
| Active-pressure HPA target | compare/sweep workflow exists; old reports support only conservative platform claims | complete reports with queue, DCGM, latency, and ordering checks |
| Batching scheduler tradeoffs | profiles exist; result matrix pending | each case/profile pair with latency, throughput, queue, GPU, and memory fields |
| Request pattern utilization | catalog exists; result matrix pending | steady, burst, uneven-size, and spike-to-zero runs on one profile |
| Cost per useful work | catalog exists; result matrix pending | successful work, failed work, p95/p99 SLO, serving cost, and tokens/sec |
| Prefill vs decode timing | streaming runner exists; curated results pending | TTFT, inter-token latency, total latency, and streamed throughput |
| Blackwell FP4 | renderers and cost model exist; live p6-b200 attempt blocked by `UnfulfillableCapacity` | BF16, NVFP4, and SmoothQuant runs with accuracy, latency, throughput, memory, and cost |

## Evidence Rules

- Use ignored generated reports as raw inputs.
- Promote representative, explainable results into `experiments/<name>/results.md`.
- Keep this page about architecture decisions, not every run.
- Do not claim GPU efficiency, batching tradeoffs, or optimized autoscaling
  targets from partial reports with missing DCGM or queue fields.
