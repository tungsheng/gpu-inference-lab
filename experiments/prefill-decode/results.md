# Prefill Vs Decode Timing Results

Status: no curated live-cluster run recorded yet.

## Run Matrix

| Case | Prompt token target | Output token cap | p50 TTFT | p95 TTFT | p50 inter-token latency | p95 inter-token latency | p95 latency | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `prefill-heavy` | 1536 | 64 | n/a | n/a | n/a | n/a | n/a | pending |
| `decode-heavy` | 128 | 768 | n/a | n/a | n/a | n/a | n/a | pending |

## Graphs

Graphs should be generated from checked-in JSON reports and stored under
`graphs/`.

Planned graphs:

- case versus p95 TTFT
- case versus p95 inter-token latency
- case versus p99 request latency
- case versus streamed chunk throughput

## Conclusion

Pending measured results.
