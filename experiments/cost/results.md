# Cost Per Useful Work Results

No curated production run has been recorded yet.

## Planned Comparison

Run each workload case against:

| Profile | Hourly serving cost | p95 SLO | p99 SLO | Result status |
| --- | ---: | ---: | ---: | --- |
| `naive-single` | 0.526 | 2.0s | 5.0s | pending |
| `optimized-batched` | 0.526 | 2.0s | 5.0s | pending |

## Result Template

For each case/profile pair, record:

- completed, successful, and failed requests
- generated tokens
- run duration
- p95 and p99 request latency
- SLO pass/fail
- estimated serving burst cost
- cost per 1K successful requests
- cost per 1M generated tokens
- average and max GPU utilization

## Interpretation Template

Summarize whether the optimized profile produced more useful work per dollar
without violating the latency SLO. Failed requests must stay out of the useful
request denominator, and the cost scope must remain serving-GPU-only unless a
later change intentionally expands the model.
