# Experiments Summary

This document is the curated rollup for experiment outcomes. Raw per-run
artifacts still belong under `docs/reports/`; experiment narratives and graphs
belong under `experiments/<name>/`.

## Current Experiment Catalog

| Experiment | Status | Primary question | Location |
| --- | --- | --- | --- |
| KV cache vs concurrency | scaffolded with load and serving renderers | How does longer prompt context reduce stable concurrency and throughput? | `experiments/kv-cache/` |
| Prefill vs decode timing | scaffolded with streaming runner | How do long-prompt/short-output and short-prompt/long-output requests shift TTFT and decode timing? | `experiments/prefill-decode/` |

## Reading Results

Each completed experiment should summarize:

- the serving profile and model settings
- the workload cases that were run
- success and failure counts
- p50, p95, and p99 latency
- p95 or p99 time to first token when available
- throughput in requests/sec and tokens/sec
- GPU utilization and GPU memory pressure
- cost per useful request or generated token when cost is relevant
- the practical systems conclusion

## Current State

The first five implementation slices add the catalog, local load-job renderer,
serving-profile renderer, report scaffold contract, a live one-case load
runner, and a streaming runner for prefill/decode timing. No production
results have been recorded yet.
