# KV Cache Vs Concurrency Results

> Auditable evidence: the reports behind these tables are committed under
> `evidence/`. Replay them without a cluster with
> `./scripts/experiment replay --experiment kv-cache`.

Status: `8192/300` long-context rate sweep has a measured saturation knee; the
1.05-1.20 req/s probes, 1.10-1.20 req/s variance repeats, and the `1.25 req/s`
admission-control comparison are populated. The `1.20 req/s` scheduler
follow-up is populated and did not beat the default long-context profile.

The latest populated reports show a single-replica long-context envelope that is
usable through `1.10 req/s` without waiting, starts queueing repeatably at
`1.15 req/s`, and is clearly queue-dominated by `1.20 req/s`. It begins queueing
hard by `1.25 req/s` and is clearly overloaded at `1.50 req/s`. The
admission-capped `1.25 req/s` run converts that overload into explicit dropped
demand and much lower tail latency. The latest direct and admission-control
reruns also capture k6 HTTP phase timing and vLLM server timing: the direct run
shows large server-side queue and TTFT inflation, while the admission-capped run
keeps queue delay near zero and leaves decode time roughly unchanged. GPU/DCGM
fields are now present in the newest reports, so memory and utilization can be
used as supporting evidence for the long-context story.

The variance repeats are low-noise at the decision boundary. The `1.10 req/s`
r2/r3 runs both delivered all 659 requests with zero waiting and p95 latency
near 25.23s. The `1.15 req/s` r2/r3 runs both delivered all 689 requests but
repeated p95 queue delay near 14.02s and peak active pressure near 47-48. The
`1.20 req/s` r2/r3 runs both delivered all 719 requests but repeated p95 queue
delay near 36.8s and peak active pressure at 71.

Scheduler variants at `1.20 req/s` did not improve the practical edge. Lowering
`max_num_seqs` to 16 or 24 increased waiting pressure and tail latency, and
raising `max_num_batched_tokens` to 16384 was roughly baseline-shaped but still
slightly worse on p95/p99 latency.

## Evidence Boundaries

- Current high-signal evidence is for the `8192/300` case on the
  `long-context` serving profile.
- The `1.50 req/s` reports were generated before the interrupted-iteration
  parser fix, so their JSON undercounts final graceful-stop backlog. The k6 logs
  show 132-134 interrupted iterations after the summary block.
- `512/100` and `2048/200` have long-context reports, but the clearest capacity
  knee so far is the `8192/300` sweep.
- New reports include offered iterations, unserved iterations, delivery ratio,
  and buffering pressure derived from both dropped and interrupted work.
- Reports generated after the client-timing instrumentation include k6 HTTP
  phase timing. Treat `client_waiting` as time to first byte, not as a
  dedicated server-side queue histogram.
- Reports generated after the server-timing instrumentation include vLLM
  queue, prefill, decode, TTFT, inter-token, and end-to-end histograms when the
  active vLLM image exposes them.

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
| `prompt-8192-output-300-rate-110-r2` | 1.10 req/s | 659 | 0 | 0 / 0 | 25.23s | 25.54s | 0.915 | 274.58 | 0 / 28 / 28 | 91% / 100% | 14.09 / 0.65 GiB | stable repeat |
| `prompt-8192-output-300-rate-110-r3` | 1.10 req/s | 659 | 0 | 0 / 0 | 25.23s | 25.37s | 0.915 | 274.58 | 0 / 28 / 28 | 84% / 100% | 14.10 / 0.64 GiB | stable repeat |
| `prompt-8192-output-300-rate-115` | 1.15 req/s | 689 | 0 | 0 / 0 | 35.35s | 35.72s | 0.957 | 287.08 | 8 / 32 / 40 | 83% / 100% | 14.10 / 0.64 GiB | queueing begins |
| `prompt-8192-output-300-rate-115-r2` | 1.15 req/s | 689 | 0 | 0 / 0 | 42.44s | 42.91s | 0.957 | 287.08 | 15 / 32 / 47 | 83% / 100% | 14.10 / 0.64 GiB | queueing repeats |
| `prompt-8192-output-300-rate-115-r3` | 1.15 req/s | 689 | 0 | 0 / 0 | 42.49s | 42.90s | 0.957 | 287.08 | 16 / 32 / 48 | 85% / 100% | 14.10 / 0.64 GiB | queueing repeats |
| `prompt-8192-output-300-rate-120` | 1.20 req/s | 719 | 0 | 0 / 0 | 54.35s | 55.25s | 0.999 | 299.58 | 30 / 32 / 62 | 83% / 100% | 14.10 / 0.64 GiB | practical edge |
| `prompt-8192-output-300-rate-120-r2` | 1.20 req/s | 719 | 0 | 0 / 0 | 62.66s | 63.27s | 0.999 | 299.58 | 39 / 32 / 71 | 89% / 100% | 14.10 / 0.64 GiB | queue-dominated |
| `prompt-8192-output-300-rate-120-r3` | 1.20 req/s | 719 | 0 | 0 / 0 | 63.40s | 64.03s | 0.999 | 299.58 | 39 / 32 / 71 | 94% / 100% | 14.10 / 0.64 GiB | queue-dominated |
| `prompt-8192-output-300-rate-125` | 1.25 req/s | 749 | 0 | 0 / 0 | 77.51s | 78.59s | 1.036 | 310.66 | 57 / 32 / 89 | 88% / 100% | 14.10 / 0.64 GiB | saturation begins |
| `prompt-8192-output-300-rate-125-admission-032` | 1.25 req/s | 690 | 0 | 59 / 0 | 27.98s | 28.02s | 0.958 | 287.50 | 0 / 32 / 32 | 91% / 100% | 14.10 / 0.64 GiB | bounded admission |
| `prompt-8192-output-300-rate-150` | 1.50 req/s | 744 | 0 | 23 / 132+ | 180.27s | 185.01s | 0.992 | 297.60 | 181 / 32 / 213 | 80% / 100% | 13.98 / 0.76 GiB | overloaded |
| `prompt-8192-output-300` | 2.00 req/s | 833 | 0 | 187 / 239 | 223.07s | 230.55s | 1.111 | 333.20 | 283 / 32 / 315 | n/a | n/a | saturated |

## Scheduler Profile Follow-Up At 1.20 Req/s

All `1.20 req/s` scheduler profiles delivered the same 719 successful requests
with zero failures or dropped/interrupted work, so the decision is about tail
latency and pressure shape.

| Profile | Max seqs | Max batched tokens | Successful requests | p95 latency | p99 latency | Requests/sec | Generated tokens/sec | Peak waiting / running / active | GPU avg / max | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `long-context` | 32 | 9216 | 719 | 54.35s | 55.25s | 0.999 | 299.58 | 30 / 32 / 62 | 83% / 100% | baseline practical edge |
| `long-context-seqs-16` | 16 | 9216 | 719 | 76.24s | 77.39s | 0.980 | 293.99 | 66 / 16 / 82 | 83% / 97% | worse tail and waiting |
| `long-context-seqs-24` | 24 | 9216 | 719 | 61.36s | 62.50s | 0.999 | 299.58 | 45 / 24 / 69 | 82% / 100% | worse tail and waiting |
| `long-context-batched-16384` | 32 | 16384 | 719 | 55.58s | 56.76s | 0.999 | 299.58 | 31 / 32 / 63 | 88% / 100% | no improvement |

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
for `8192/300` requests. The original run showed peak waiting at 8 and p95
latency near 35s; r2/r3 repeated the queueing signal with peak waiting 15-16,
p95 server queue delay near 14.02s, and p95 request latency near 42.5s.
Observed that `1.20 req/s` keeps full delivery but is queue-dominated. The
original run showed peak waiting at 30 and p95 latency near 54s; r2/r3 repeated
the practical-edge signal with peak waiting 39, p95 server queue delay near
36.8s, and p95 request latency near 63s.
Observed that `1.25 req/s` saturates the vLLM scheduler, with 57 waiting
requests, p95 latency near 78s, p95 server queue delay near 48s, and GPU max at
100%.

Observed that `1.50 req/s` lets excess demand turn into long tail latency and
graceful-stop backlog; added an admission-control comparison capped at 32 k6 VUs
so overload is reported as explicit unmet demand instead of only as delayed
completion.

Observed that the `1.25 req/s` admission-control probe capped active work at 32
requests, eliminated serving-side waiting pressure, reduced p95 latency from
77.51s to 27.98s, and reported 59 dropped client iterations as explicit
unserved demand. Generated throughput fell from 310.66 to 287.50 tokens/sec, so
the trade is lower tail latency and clearer backpressure at lower completed
volume. The server-timing rerun reports p95 queue delay dropping from 48.11s to
0.285s and p95 TTFT dropping from 71.24s to 0.718s, while p95 decode is
effectively unchanged at about 29.4s. Client timing shows negligible network
overhead, with p95 blocked, connect, send, and receive phases all below 2 ms.
That makes the tail a server-side queueing issue, not a client/network artifact.

Observed that the checked-in `long-context` profile might be too aggressive at
`max_num_seqs=32`; added `long-context-seqs-16`, `long-context-seqs-24`, and
`long-context-batched-16384` variants to measure whether lower sequence
concurrency or a larger batched-token budget improves tail latency. The
`1.20 req/s` follow-up rejected that path: `seqs-16` increased p95 latency to
76.24s with peak active pressure 82, `seqs-24` increased p95 to 61.36s with
peak active pressure 69, and `batched-16384` landed near baseline but still
worse at 55.58s p95 with peak active pressure 63. Use admission/backpressure
for this knee before pursuing scheduler caps further on the current g4dn/vLLM
`v0.9.0` path.

## Next Runs

1. Add admission-cap variants for `1.15-1.20 req/s` only when selecting a
   production backpressure target; compare delivery ratio, dropped demand, p95
   queue delay, and p95 request latency rather than decode time.
2. If an uncapped service-rate target is needed, narrow between `1.10` and
   `1.15 req/s` before treating the boundary as production-safe.
3. Use `./scripts/experiment summarize-reports --experiment kv-cache` after each
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

- [Long-context knee](graphs/long-context-knee.svg) visualizes the `8192/300`
  p95-latency knee and the `1.25 req/s` admission-control comparison.

Remaining planned graphs:

- target rate versus delivery ratio and unserved iterations for `8192/300`
- target rate versus peak waiting/running/active requests for `8192/300`
- prompt length versus max stable rate after the `512`, `2048`, and `8192`
  long-context matrix is complete
- profile variant versus tail latency and throughput near the saturation knee
- prompt length versus peak GPU memory once DCGM fields are populated across the
  comparable matrix
