# Evidence

Curated cross-experiment readout: what the repository supports, what remains a
hypothesis, and where the source details live.

Generated artifacts under `docs/reports/` are ignored by default. Stable
experiment conclusions belong in `experiments/<name>/results.md`; this page
connects them to decisions.

For the current action-oriented readout, see
[Recommendations](recommendations.md).

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

### Active-Pressure HPA Tuning

Source: `docs/reports/evaluate-warm-1-compare-20260514-174643-compare.md` and
`docs/reports/evaluate-zero-idle-active-pressure-sweep-20260514-191700-active-pressure-sweep.md`

The active-pressure HPA path now has fresh complete compare and sweep reports.
In the warm-one comparison, both the running-request policy and active-pressure
policy stayed underutilized with no measured queue pressure. Active pressure
made the second replica ready faster, but did not improve the run-level
throughput or cost result.

| Policy | Target metric | p95 latency | p95 queue wait | Avg requests/sec | Avg GPU | Second ready replica | Burst cost | Assessment |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| running | `vllm_requests_running=128` | 117s | 0s | 2.41 | 23.5% | 966s | 0.396254 | underutilized |
| active-pressure | `vllm_requests_active=6` | 117s | 0s | 2.30 | 19.8% | 571s | 0.447684 | underutilized |

The zero-idle active-pressure sweep evaluated targets `2`, `4`, `6`, and `8`.
All targets were classified as underutilized; the report recommended target
`8` only because no balanced target was found and the highest underutilized
target should increase useful GPU work without creating current queue pressure.

| Active target | p95 TTFT | Peak waiting | Avg GPU | Peak active NodeClaims | Second ready replica | Burst cost | Assessment |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 2 | 0.105s | 0 | 15.7% | 2 | 906s | 0.486696 | underutilized |
| 4 | 0.089s | 1 | 16.3% | 2 | 943s | 0.491810 | underutilized |
| 6 | 0.090s | 1 | 17.6% | 3 | 904s | 0.484650 | underutilized |
| 8 | 0.090s | 0 | 17.4% | 2 | 926s | 0.480121 | underutilized |

Decision impact: active-pressure HPA is measurable and safe to keep testing,
but the current target recommendation is not a production optimum. The next HPA
experiment should raise pressure or adjust capacity shape until at least one
target reaches the balanced band.

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
| `1.25 req/s` | saturation begins | p95 `77.51s`, p95 queue `48.11s`, peak waiting `57`, active `89` |
| `1.25 req/s, active capped at 32` | bounded admission | p95 `27.98s`, p95 queue `0.285s`, dropped `59`, peak active `32` |
| `1.50 req/s` | overloaded | p95 `180.27s`, dropped/interrupted backlog |

Decision impact: long-context serving needs a concurrency and admission
boundary. A profile can have zero request failures and still miss the SLO
because queueing and tail latency explode. Capping active long-context work
turns some demand into explicit backpressure while materially reducing tail
latency. The server-timing rerun shows the mechanism: admission removes queue
and TTFT inflation while decode time remains roughly unchanged.

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

### Small-Request Scheduler Defaults

Source: `experiments/batching/results.md`

For steady and burst homogeneous `512/128` traffic, vLLM's dynamic defaults
completed the most useful work with the lowest tail latency among the measured
profiles.

| Case | Profile | Delivery ratio | p95 latency | Requests/sec | Generated tokens/sec | Peak waiting |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| steady | `dynamic-default` | 1.000000 | 1.66s | 7.41 | 948.98 | 0 |
| steady | `limited-batching` | 0.801049 | 10.55s | 5.94 | 760.18 | 56 |
| steady | `constrained-scheduler` | 0.156180 | 59.72s | 1.07 | 136.86 | 63 |
| burst | `dynamic-default` | 0.975670 | 6.79s | 14.11 | 1805.78 | 1 |
| burst | `limited-batching` | 0.455497 | 20.53s | 6.19 | 791.92 | 120 |
| burst | `constrained-scheduler` | 0.084078 | 119.09s | 1.07 | 137.03 | 127 |

Decision impact: keep the dynamic default scheduler as the steady small-request
baseline unless a different workload proves that explicit caps protect latency
or fairness.

### Request Pattern Utilization

Source: `experiments/request-patterns/results.md`

The default profile was measured across steady, burst, uneven-size, and
spike-to-zero traffic. Steady homogeneous traffic stayed stable, while bursty
patterns drove active concurrency to the edge and converted excess work into
client-side drops.

| Case | Delivery ratio | p95 latency | Requests/sec | Tokens/sec | Peak active | Avg GPU | Max GPU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `steady-small` | 1.000000 | 1.29s | 5.90 | 755.60 | 7 | 69.0% | 84% |
| `burst-small` | 0.874713 | 8.56s | 13.36 | 1709.53 | 127 | 77.3% | 79% |
| `uneven-size-mix` | 0.997003 | 7.87s | 7.39 | 949.51 | 25 | 65.2% | 84% |
| `spike-to-zero` | 0.797561 | 8.45s | 14.10 | 1805.15 | 128 | 75.5% | 76% |

Decision impact: traffic shape materially changes useful throughput, latency,
memory pressure, and delivery ratio. Scheduler and admission recommendations
need pattern-specific evidence, not only a steady baseline.

### Cost Per Useful Work

Source: `experiments/cost/results.md`

On the same `$0.526/hour` serving-GPU cost model, the optimized batched profile
produced much more useful work per dollar than the naive single-request profile.
Only the steady optimized case met the 2s p95 and 5s p99 request-latency SLO.

| Case | Profile | Successful | Dropped | p95 latency | SLO | Cost/1K successful | Cost/1M tokens |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: |
| `steady-cost-efficiency` | `naive-single` | 413 | 2227 | 60.31s | false | $0.137976 | $1.077936 |
| `steady-cost-efficiency` | `optimized-batched` | 2670 | 0 | 1.61s | true | $0.019752 | $0.154313 |
| `burst-cost-efficiency` | `naive-single` | 227 | 2882 | 120.00s | false | $0.164137 | $1.282317 |
| `burst-cost-efficiency` | `optimized-batched` | 2570 | 677 | 10.91s | false | $0.012768 | $0.099748 |

Decision impact: batching is strongly supported for small-request economics,
but burst SLO compliance still needs admission, autoscaling, or more capacity.

### Prefill And Decode Timing

Source: `experiments/prefill-decode/results.md`

The default streaming profile separates prompt-processing pressure from
generation pressure:

| Case | p95 TTFT | p95 inter-token latency | p95 request latency | Outcome |
| --- | ---: | ---: | ---: | --- |
| `prefill-heavy` | 1.371s | 0.014s | 2.245s | prompt processing dominates first-token delay |
| `decode-heavy` | 0.149s | 0.011s | 8.408s | decode length dominates total latency |
| `mixed-prefill-decode` | 0.454s | 0.014s | 12.524s | decode-heavy requests dominate mixed tail latency |

Decision impact: do not rely on request latency alone for streamed workloads.
Long prompts need a TTFT SLO; long outputs need total latency and inter-token
latency checks.

## Partial Or Pending Evidence

| Area | State | Recommendation needs |
| --- | --- | --- |
| Active-pressure HPA target | fresh compare and zero-idle sweep reports are complete, but all tested targets were underutilized | repeat under higher pressure or alternate capacity shapes before selecting a production target |
| Server-side timing breadth | direct and admission-capped `1.25 req/s` long-context reruns now separate queue, prefill, decode, TTFT, inter-token, and e2e timing; older reports still predate those histograms | repeat targeted cases when changing vLLM versions, scheduler profiles, or admission caps |
| Batching scheduler breadth | steady and burst matrices support dynamic default for homogeneous `512/128`; fairness and richer mixed-size cases remain pending | mixed request-size and fairness runs before generalizing scheduler caps |
| Prefill/decode profile tuning | default and mixed scheduler reports exist; repeat or variant sweeps remain pending | variance checks or new profiles before making broad scheduler claims |
| Blackwell FP4 | renderers and cost model exist; live p6-b200 attempt blocked by `UnfulfillableCapacity` | BF16, NVFP4, and SmoothQuant runs with accuracy, latency, throughput, memory, and cost |

## Evidence Rules

- Use ignored generated reports as raw inputs.
- Promote representative, explainable results into `experiments/<name>/results.md`.
- Keep this page about architecture decisions, not every run.
- Do not claim optimized autoscaling targets from underutilized sweeps or
  partial reports with missing DCGM or queue fields.
