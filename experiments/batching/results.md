# Batching Scheduler Tradeoffs Results

No curated production run has been recorded yet.

## Planned Comparison

Run each workload case against:

| Profile | Max sequences | Max batched tokens | Result status |
| --- | ---: | ---: | --- |
| `constrained-scheduler` | 1 | 2048 | pending |
| `limited-batching` | 8 | 4096 | pending |
| `dynamic-default` | n/a | n/a | pending |

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
