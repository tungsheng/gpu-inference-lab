# KV Cache Vs Concurrency Results

Status: no curated representative live-cluster matrix recorded yet.

One ignored local default-profile smoke run completed the `512/100` case with
3659 successful requests, zero failed requests, p95 latency near 0.946s, and
about 5.08 requests/sec. Treat that as runner/platform evidence only, not as
part of the final KV-cache comparison. The curated comparison should rerun all
cases against `long-context` so profile differences do not explain the result.

## Run Matrix

| Case | Prompt token target | Output token cap | Max stable concurrency | p95 latency | p99 latency | Avg tokens/sec | Peak GPU memory | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `prompt-512-output-100` | 512 | 100 | n/a | n/a | n/a | n/a | n/a | pending |
| `prompt-2048-output-200` | 2048 | 200 | n/a | n/a | n/a | n/a | n/a | pending |
| `prompt-8192-output-300` | 8192 | 300 | n/a | n/a | n/a | n/a | n/a | pending |

## Graphs

Graphs should be generated from checked-in JSON reports and stored under
`graphs/`.

Planned graphs:

- prompt length versus max stable concurrency
- prompt length versus peak GPU memory
- prompt length versus p99 latency
- prompt length versus generated tokens/sec

## Conclusion

Pending representative measured results. Do not claim KV-cache memory pressure
as the primary constraint until the full matrix has non-null GPU memory and
utilization signals.
