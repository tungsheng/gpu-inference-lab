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
| KV cache vs concurrency | renderable locally; measurable with `run` | How does longer prompt context reduce stable concurrency and throughput? | `experiments/kv-cache/` |
| Prefill vs decode timing | renderable locally; measurable with `run-stream` | How do prompt-heavy and decode-heavy requests shift TTFT and inter-token timing? | `experiments/prefill-decode/` |
| Batching scheduler tradeoffs | renderable locally; measurable with `run` | How do vLLM scheduler limits trade throughput for p95/p99 latency? | `experiments/batching/` |
| Request pattern utilization | renderable locally; measurable with `run` | How do steady, burst, uneven-size, and spike-to-zero traffic patterns affect GPU occupancy? | `experiments/request-patterns/` |
| Autoscaling and queueing behavior | renderable locally; measurable with `run` | How much traffic must be buffered while GPU capacity and model readiness catch up? | `experiments/autoscaling/` |
| Cost per useful work | renderable locally; measurable with `run` | How much cheaper does the same GPU become when concurrency and batching produce more successful work? | `experiments/cost/` |

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

## Evidence Gate

Current ignored local reports are useful platform-validation evidence. They can
support conservative claims such as:

- zero-idle serving reported `$0/hr` idle serving-GPU cost and cleaned GPU nodes
  back to zero
- one warm-baseline compare run showed active-pressure reached the second Ready
  replica faster than running-request scaling, `564s` versus `989s`
- the k6/evaluate workflows report latency, TTFT, queue estimates, scale-out
  timing, and serving cost

Do not use the current reports to claim measured GPU utilization, KV cache as
the primary constraint, batching throughput/p99 tradeoffs, or an optimized
active-pressure target. Those conclusions require representative checked-in
JSON reports with non-null DCGM fields and complete experiment matrices.

## Current Gap

The catalog and runners exist, but representative curated live-cluster result
matrices have not been recorded yet. Until representative runs are selected and
checked in, treat `experiments/<name>/results.md` files as result templates
rather than final systems evidence.
