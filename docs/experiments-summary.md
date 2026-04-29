# Experiments Summary

This is the curated experiment rollup. Generated per-run artifacts belong under
`docs/reports/` and are ignored by default. Stable conclusions belong in
`experiments/<name>/results.md`.

Run this after changing experiment definitions, cases, profiles, templates, or
schemas:

```bash
./scripts/experiment validate
```

## Catalog

| Experiment | Status | Primary question | Location |
| --- | --- | --- | --- |
| KV cache vs concurrency | runnable one-case load runner | How does longer prompt context reduce stable concurrency and throughput? | `experiments/kv-cache/` |
| Prefill vs decode timing | runnable streaming runner | How do prompt-heavy and decode-heavy requests shift TTFT and inter-token timing? | `experiments/prefill-decode/` |
| Batching scheduler tradeoffs | runnable serving-profile comparison | How do vLLM scheduler limits trade throughput for p95/p99 latency? | `experiments/batching/` |
| Request pattern utilization | runnable mixed-shape load renderer | How do steady, burst, uneven-size, and spike-to-zero traffic patterns affect GPU occupancy? | `experiments/request-patterns/` |
| Autoscaling and queueing behavior | runnable direct/queued client policies | How much traffic must be buffered while GPU capacity and model readiness catch up? | `experiments/autoscaling/` |
| Cost per useful work | runnable cost and SLO profiles | How much cheaper does the same GPU become when concurrency and batching produce more successful work? | `experiments/cost/` |

## Result Standard

Each completed experiment should summarize:

- serving profile and model settings
- workload cases that were run
- success, failure, and dropped-iteration counts
- p50, p95, and p99 latency
- TTFT or inter-token latency when relevant
- throughput in requests/sec and tokens/sec
- GPU utilization and memory pressure when available
- cost per useful request or generated token when cost is relevant
- the practical systems conclusion

## Current Gap

The catalog and runners exist, but curated production results have not been
recorded yet. Until representative runs are selected and checked in, treat
`experiments/<name>/results.md` files as result templates rather than evidence.
