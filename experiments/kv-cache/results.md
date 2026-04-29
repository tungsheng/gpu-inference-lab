# KV Cache Vs Concurrency Results

Status: no curated production run recorded yet.

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

Pending measured results.
