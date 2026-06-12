# KV Cache Observatory Results

Status: planned. The catalog and local observatory renderer are present; live
vLLM `0.22.1` reports are pending.

## Promotion Gates

| Gate | Requirement |
| --- | --- |
| Modern serving target | `modern-vllm-0221` starts and exposes vLLM metrics. |
| Hit/miss contrast | `shared-system-prompt` reports higher prefix-cache hit rate than `cache-miss-storm`. |
| Pressure diagnosis | `long-context-workload` correlates KV utilization with queue, prefill, decode, and tail latency. |
| Trace clarity | Request A/B/C timeline artifacts identify observed versus derived block events. |

## Evidence Boundaries

- Do not mix historical `experiments/kv-cache` vLLM `0.9.0` conclusions into
  this result page unless the table explicitly labels them as historical.
- Per-request physical block ownership is evidence only when the run includes
  vLLM KV events or an explicit observatory trace.
- Missing KV block, eviction, or reload metrics must remain `n/a` or `null`;
  they should not be inferred from latency alone.

## Planned Graphs

- Request A/B/C KV block allocation over time
- prefix-cache hit tokens versus miss tokens
- KV utilization versus p95 queue, prefill, and decode latency
- evictions and reloads over the run window when available
