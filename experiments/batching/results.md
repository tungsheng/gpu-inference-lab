# Batching Scheduler Tradeoffs Results

Status: the steady and burst `512/128` cases have complete live-cluster profile
matrices. Both cases support the same current conclusion: the unchecked vLLM
dynamic scheduler defaults outperform the explicit caps for this small-request
workload.

## Steady Live Cluster Run - 2026-05-05

All runs used the same `steady-512-output-128` workload at an 8 req/s target.

| Profile | Max sequences | Max batched tokens | Successful | Dropped / interrupted | Delivery ratio | p95 latency | p99 latency | Requests/sec | Generated tokens/sec | Peak waiting / running / active | GPU avg / max | GPU memory used / free | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `dynamic-default` | n/a | n/a | 2669 | 0 / 0 | 1.000000 | 1.66s | 1.68s | 7.41 | 948.98 | 0 / 13 / 13 | 82.83% / 85% | 11.59 / 3.15 GiB | best steady profile |
| `limited-batching` | 8 | 4096 | 2138 | 531 / 0 | 0.801049 | 10.55s | 10.60s | 5.94 | 760.18 | 56 / 8 / 64 | 82.17% / 85% | 12.71 / 2.03 GiB | queue-limited |
| `constrained-scheduler` | 1 | 2048 | 417 | 2223 / 30 | 0.156180 | 59.72s | 59.74s | 1.07 | 136.86 | 63 / 1 / 64 | 87.50% / 88% | 12.75 / 1.99 GiB | overloaded reference |

## Burst Live Cluster Run - 2026-05-14

All runs used the same `burst-512-output-128` workload at a 16 req/s target.

| Profile | Max sequences | Max batched tokens | Successful | Dropped / interrupted | Delivery ratio | p95 latency | p99 latency | Requests/sec | Generated tokens/sec | Peak waiting / running / active | GPU avg / max | GPU memory used / free | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `dynamic-default` | n/a | n/a | 3168 | 79 / 0 | 0.975670 | 6.79s | 6.98s | 14.11 | 1805.78 | 1 / 107 / 107 | 81.00% / 82% | 12.80 / 1.95 GiB | best burst profile |
| `limited-batching` | 8 | 4096 | 1479 | 1768 / 0 | 0.455497 | 20.53s | 20.55s | 6.19 | 791.92 | 120 / 8 / 128 | 83.25% / 84% | 12.71 / 2.03 GiB | queue-limited |
| `constrained-scheduler` | 1 | 2048 | 273 | 2880 / 94 | 0.084078 | 119.09s | 119.11s | 1.07 | 137.03 | 127 / 1 / 128 | 70.20% / 89% | 12.73 / 2.01 GiB | overloaded reference |

## Reports

- `dynamic-default`: `docs/reports/experiment-batching-steady-512-output-128-dynamic-default-20260505-232357.json`
- `limited-batching`: `docs/reports/experiment-batching-steady-512-output-128-limited-batching-20260505-233925.json`
- `constrained-scheduler`: `docs/reports/experiment-batching-steady-512-output-128-constrained-scheduler-20260505-235019.json`
- `dynamic-default` burst: `docs/reports/experiment-batching-burst-512-output-128-dynamic-default-20260514-155838.json`
- `limited-batching` burst: `docs/reports/experiment-batching-burst-512-output-128-limited-batching-20260514-160416.json`
- `constrained-scheduler` burst: `docs/reports/experiment-batching-burst-512-output-128-constrained-scheduler-20260514-160946.json`

## Interpretation

For steady and burst homogeneous `512/128` traffic, the unchecked vLLM scheduler
defaults were materially better than the explicit caps. The default profile
completed the target steady load with full delivery, low tail latency, no
waiting pressure, and the highest useful token throughput. Under burst load it
still kept delivery near 98%, limited waiting pressure to one request, and
produced more than 2x the generated-token throughput of `limited-batching`.

The `limited-batching` and `constrained-scheduler` profiles did not simply trade
throughput for lower latency. Both profiles built client-side backlog and shed
work while keeping similar or lower GPU utilization, which means the caps limited
useful work before they produced a better tail-latency envelope.

Decision impact: keep `dynamic-default` as the steady small-request baseline.
Use explicit sequence or batched-token caps only when a separate workload proves
they protect latency or fairness.

## Graphs

- [Scheduler profile matrix](graphs/scheduler-profile-matrix.svg) compares
  generated-token throughput and p95 latency for the steady and burst `512/128`
  matrices.

## Follow-Ups

The current matrix covers one small homogeneous request shape. Follow-up
scheduler work should use mixed request sizes or explicit fairness goals before
adding new caps.

## Result Template

For each case/profile pair, record:

- completed requests and failed requests
- requests/sec
- generation tokens/sec when completion usage is present
- p50, p95, and p99 request latency
- p50 and p95 TTFT when available
- peak waiting, running, and active requests
- average and max GPU utilization
- GPU memory used and free

## Interpretation Template

Summarize whether the added scheduler freedom increased throughput enough to
justify any tail-latency increase. Be explicit that `dynamic-default` means the
repo did not set explicit `--max-num-seqs` or `--max-num-batched-tokens`; it
does not mean batching was disabled.
