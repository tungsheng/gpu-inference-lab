# KV Cache Vs Concurrency Results

Status: `8192/300` long-context rate sweep has a measured saturation knee; the
1.05-1.20 req/s probes are populated and scheduler/admission follow-ups are
ready.

The latest populated reports show a single-replica long-context envelope that is
usable through `1.10 req/s` without waiting, starts queueing at `1.15 req/s`,
and reaches the practical edge by `1.20 req/s`. It begins queueing hard by
`1.25 req/s` and is clearly overloaded at `1.50 req/s`. GPU/DCGM fields are now
present in the newest reports, so memory and utilization can be used as
supporting evidence for the long-context story.

## Evidence Boundaries

- Current high-signal evidence is for the `8192/300` case on the
  `long-context` serving profile.
- The `1.50 req/s` reports were generated before the interrupted-iteration
  parser fix, so their JSON undercounts final graceful-stop backlog. The k6 logs
  show 132-134 interrupted iterations after the summary block.
- `512/100` and `2048/200` have long-context reports, but the clearest capacity
  knee so far is the `8192/300` sweep.
- New reports will include offered iterations, unserved iterations, delivery
  ratio, and buffering pressure derived from both dropped and interrupted work.

## 8192/300 Long-Context Sweep

Stable means zero request failures, zero dropped iterations, zero interrupted
iterations, high delivery ratio, and no sustained waiting-request pressure.

| Case | Target rate | Successful requests | Failed requests | Dropped / interrupted | p95 latency | p99 latency | Requests/sec | Generated tokens/sec | Peak waiting / running / active | GPU avg / max | GPU memory used / free | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `prompt-8192-output-300-rate-010` | 0.10 req/s | 59 | 0 | n/a / 0 | 4.39s | 4.41s | 0.082 | 24.58 | 0 / 1 / 1 | n/a | n/a | stable |
| `prompt-8192-output-300-rate-015` | 0.15 req/s | 89 | 0 | n/a / 0 | 4.31s | 4.34s | 0.124 | 37.08 | 0 / 1 / 1 | n/a | n/a | stable |
| `prompt-8192-output-300-rate-020` | 0.20 req/s | 119 | 0 | n/a / 0 | 4.34s | 4.37s | 0.165 | 49.58 | 0 / 1 / 1 | n/a | n/a | stable |
| `prompt-8192-output-300-rate-025` | 0.25 req/s | 150 | 0 | n/a / 0 | 4.83s | 4.89s | 0.207 | 62.14 | 0 / 2 / 2 | n/a | n/a | stable |
| `prompt-8192-output-300-rate-050` | 0.50 req/s | 299 | 0 | n/a / 0 | 5.28s | 5.31s | 0.415 | 124.58 | 0 / 3 / 3 | n/a | n/a | stable |
| `prompt-8192-output-300-rate-075` | 0.75 req/s | 449 | 0 | 0 / 0 | 6.61s | 7.03s | 0.624 | 187.08 | 0 / 5 / 5 | 58% / 96% | 14.10 / 0.64 GiB | stable |
| `prompt-8192-output-300-rate-100` | 1.00 req/s | 599 | 0 | 0 / 0 | 11.92s | 12.69s | 0.832 | 249.58 | 0 / 12 / 12 | 90% / 100% | 14.10 / 0.64 GiB | stable |
| `prompt-8192-output-300-rate-105` | 1.05 req/s | 630 | 0 | 0 / 0 | 14.31s | 15.00s | 0.870 | 260.97 | 0 / 16 / 16 | 80% / 100% | 14.03 / 0.71 GiB | stable |
| `prompt-8192-output-300-rate-110` | 1.10 req/s | 659 | 0 | 0 / 0 | 21.67s | 21.87s | 0.915 | 274.58 | 0 / 24 / 24 | 82% / 100% | 14.10 / 0.64 GiB | stable but tail rising |
| `prompt-8192-output-300-rate-115` | 1.15 req/s | 689 | 0 | 0 / 0 | 35.35s | 35.72s | 0.957 | 287.08 | 8 / 32 / 40 | 83% / 100% | 14.10 / 0.64 GiB | queueing begins |
| `prompt-8192-output-300-rate-120` | 1.20 req/s | 719 | 0 | 0 / 0 | 54.35s | 55.25s | 0.999 | 299.58 | 30 / 32 / 62 | 83% / 100% | 14.10 / 0.64 GiB | practical edge |
| `prompt-8192-output-300-rate-125` | 1.25 req/s | 749 | 0 | 0 / 0 | 93.78s | 95.84s | 1.010 | 303.05 | 72 / 32 / 104 | 75% / 100% | 12.16 / 2.58 GiB | saturation begins |
| `prompt-8192-output-300-rate-150` | 1.50 req/s | 744 | 0 | 23 / 132+ | 180.27s | 185.01s | 0.992 | 297.60 | 181 / 32 / 213 | 80% / 100% | 13.98 / 0.76 GiB | overloaded |
| `prompt-8192-output-300` | 2.00 req/s | 833 | 0 | 187 / 239 | 223.07s | 230.55s | 1.111 | 333.20 | 283 / 32 / 315 | n/a | n/a | saturated |

## Failure To Fix To Result

Observed that the original 8192-token prompt generator could overshoot the
serving profile's context budget and produce fast request failures; replaced it
with a repeated common token-like word, allowing valid long-context completions
for the `8192/300` workload.

Observed that fractional arrival rates caused k6 job startup failures because
the executor requires integer targets; rendered fractional rates as integer
arrivals over exact time windows, enabling the low-rate and knee stability
sweeps.

Observed that missing DCGM runtime wiring left GPU utilization and memory fields
as `n/a`; mounted kubelet pod resources into dcgm-exporter and supplied
`NODE_NAME`, restoring GPU metrics in the latest reports.

Observed that `1.15 req/s` is the first populated rate to show waiting pressure
for `8192/300` requests, with peak waiting at 8 and p95 latency near 35s.
Observed that `1.20 req/s` keeps full delivery but reaches the practical edge,
with peak waiting at 30, `max_num_seqs=32`, and p95 latency near 54s.
Observed that `1.25 req/s` saturates the vLLM scheduler, with 72 waiting
requests, p95 latency near 94s, and GPU max at 100%.

Observed that `1.50 req/s` lets excess demand turn into long tail latency and
graceful-stop backlog; added an admission-control comparison capped at 32 k6 VUs
so overload is reported as explicit unmet demand instead of only as delayed
completion.

Observed that the checked-in `long-context` profile may be too aggressive at
`max_num_seqs=32`; added `long-context-seqs-16`, `long-context-seqs-24`, and
`long-context-batched-16384` variants to measure whether lower sequence
concurrency or a larger batched-token budget improves tail latency.

## Next Runs

1. Run `rate-110-r2/r3`, `rate-115-r2/r3`, and `rate-120-r2/r3` to quantify
   variance near the knee.
2. Run `prompt-8192-output-300-rate-125-admission-032` on `long-context` and
   compare delivery ratio, p95 latency, dropped iterations, and unserved demand
   against the uncapped `rate-125` report.
3. Re-run `rate-115`, `rate-120`, and `rate-125` against
   `long-context-seqs-16`, `long-context-seqs-24`, and
   `long-context-batched-16384`.
4. Use `./scripts/experiment summarize-reports --experiment kv-cache` after each
   batch to keep the latest case/profile comparison visible.

## FP8 KV Cache Probe

The FP8 KV profiles keep the existing one-GPU g4dn/g5 hardware path and only
change KV cache storage or scheduler caps. The same-day
`prompt-8192-output-300-rate-100` A/B and follow-up probes did not pass the
"stable stays stable" gate:

| Profile | KV cache dtype | Calculate scales | Max seqs | Successful requests | Failed requests | Delivery ratio | Dropped / interrupted | p95 latency | Generated tokens/sec | Peak waiting / running / active | GPU avg / max | GPU memory used / free | Outcome |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `long-context` | n/a | n/a | 32 | 599 | 0 | 1.000000 | 0 / 0 | 11.92s | 249.58 | 0 / 12 / 12 | 90% / 100% | 14.10 / 0.64 GiB | stable |
| `long-context-fp8-kv` | fp8 | true | 32 | 414 | 0 | 0.691152 | 51 / 134 | 245.29s | 165.60 | 146 / 32 / 178 | 89% / 100% | 14.03 / 0.71 GiB | regressed |
| `long-context-fp8-kv-static-scales` | fp8 | false | 32 | 285 | 65 | 0.475793 | 87 / 162 | 300.00s | 114.00 | 181 / 32 / 213 | 90% / 98% | 14.03 / 0.71 GiB | worse |
| `long-context-fp8-kv-seqs-12` | fp8 | true | 12 | 402 | 0 | 0.671119 | 54 / 143 | 253.00s | 160.80 | 168 / 12 / 180 | 89% / 100% | 14.03 / 0.71 GiB | still regressed |

The FP8 KV profiles save only about 0.07 GiB at this workload while reducing
generation throughput from about 250 tokens/sec to 114-166 tokens/sec. Startup
logs for the FP8 pods report CUDA compute capability below 8.0, fallback to the
vLLM V0 engine, and XFormers attention. They also report a much larger FP8 KV
block pool, with roughly 11.97 GiB reserved for KV cache and theoretical
`226.98x` concurrency for 9216-token requests.

Static scales were slower than dynamic scales, so `--calculate-kv-scales` is not
the primary regression. Capping `max_num_seqs` to the baseline observed running
depth avoided request timeouts but did not restore throughput or delivery, so
the problem is not just over-admission to 32 running sequences. The practical
conclusion is that FP8 KV is not useful for this T4/g4dn long-context profile:
the baseline is compute-bound enough that the tiny memory gain does not offset
FP8 KV overhead on the V0/XFormers path.

Next FP8-specific probes:

1. Stop the `8192/300` FP8 KV path on g4dn unless a newer vLLM image or g5/L4
   backend is being tested.
2. If FP8 must stay in scope on current hardware, run a smaller prompt case such
   as `2048/200` against `long-context` and `long-context-fp8-kv` to find
   whether FP8 only fails under long-prefill pressure.
3. If testing newer serving software, keep `long-context-fp8-kv-seqs-12` as the
   first canary before returning to the uncapped profile.
4. Do not run `rate-125` or `rate-150` FP8 KV cases on the current
   `vllm/vllm-openai:v0.9.0` g4dn path.

## Graphs

Graphs should be generated from checked-in JSON reports and stored under
`graphs/` once the comparable matrix has representative `long-context` reports.

Planned graphs:

- target rate versus p95/p99 latency for `8192/300`
- target rate versus delivery ratio and unserved iterations for `8192/300`
- target rate versus peak waiting/running/active requests for `8192/300`
- prompt length versus max stable rate after the `512`, `2048`, and `8192`
  long-context matrix is complete
- profile variant versus tail latency and throughput near the saturation knee
- prompt length versus peak GPU memory once DCGM fields are populated across the
  comparable matrix
