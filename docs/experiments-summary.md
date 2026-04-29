# Experiments Summary

This document is the curated rollup for experiment outcomes. Raw per-run
artifacts still belong under `docs/reports/`; experiment narratives and graphs
belong under `experiments/<name>/`.

Shared vLLM serving defaults live in `experiments/_profiles/`. Individual
experiments should only override the fields that matter to the question they
are asking. Run `./scripts/experiment validate` after catalog edits to check
the CSV contracts, shared defaults, serving profile overrides, and renderer
templates.

## Current Experiment Catalog

| Experiment | Status | Primary question | Location |
| --- | --- | --- | --- |
| KV cache vs concurrency | scaffolded with load and serving renderers | How does longer prompt context reduce stable concurrency and throughput? | `experiments/kv-cache/` |
| Prefill vs decode timing | scaffolded with streaming runner | How do long-prompt/short-output and short-prompt/long-output requests shift TTFT and decode timing? | `experiments/prefill-decode/` |
| Batching scheduler tradeoffs | scaffolded with scheduler profiles | How do explicit vLLM scheduler limits trade throughput for p95/p99 latency? | `experiments/batching/` |
| Request pattern utilization | scaffolded with mixed request shapes | How do steady, burst, uneven-size, and spike-to-zero traffic patterns affect GPU occupancy? | `experiments/request-patterns/` |
| Autoscaling and queueing behavior | scaffolded with direct and queued client policies | How much traffic must be buffered while GPU capacity and model readiness catch up? | `experiments/autoscaling/` |
| Cost per useful work | scaffolded with cost profiles and SLO fields | How much cheaper does the same GPU become when concurrency and batching produce more successful work? | `experiments/cost/` |

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

The first eight implementation slices add the catalog, local load-job renderer,
serving-profile renderer, report scaffold contract, a live one-case load
runner, a streaming runner for prefill/decode timing, and a batching experiment
with explicit scheduler-profile comparison. Slice seven adds request-pattern
cases plus weighted request-shape rendering for mixed-size traffic. Slice eight
adds autoscaling queueing cases with direct and queued client policies. Slice
nine adds cost profiles, useful-work denominators, and SLO pass/fail fields.
No production results have been recorded yet.
