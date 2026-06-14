# KV Cache Observatory Results

Status: live validated on June 12, 2026. The catalog, local observatory
renderer, vLLM `0.22.1` serving profile, and three promoted live reports are
present.

The promoted reports are committed under `evidence/`, so the table below is
auditable without a cluster:

```bash
./scripts/experiment replay --experiment kv-cache-observatory
```

## Live vLLM 0.22.1 Results

All rows below use `modern-vllm-0221-prefix` with
`vllm/vllm-openai:v0.22.1`. KV hit rate and KV utilization are `observed`
from vLLM/Prometheus metrics in the linked JSON reports.

| Case | Source report | Successful requests | p95 latency | p95 queue | p95 prefill | p95 decode | KV hit rate | KV utilization | GPU memory |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Shared system prompt | [JSON](evidence/experiment-kv-cache-observatory-shared-system-prompt-modern-vllm-0221-prefix-20260612-142711.json) | 1259/1259 | 1.229s | 0.285s | 0.285s | 1.475s | 97.25% | 0.289% | 14.42 GB |
| Cache miss storm | [JSON](evidence/experiment-kv-cache-observatory-cache-miss-storm-modern-vllm-0221-prefix-20260612-143551.json) | 1259/1259 | 3.955s | 0.285s | 0.285s | 4.860s | 0.00% | 3.779% | 14.42 GB |
| Long-context workload | [JSON](evidence/experiment-kv-cache-observatory-long-context-workload-modern-vllm-0221-prefix-20260612-144914.json) | 599/599 | 1.918s | 0.285s | 0.285s | 1.975s | 99.64% | 0.734% | 14.58 GB |

## Supported Conclusions

- Shared-prefix traffic produced a 97.25% observed KV hit rate and 1.229s p95
  request latency.
- Cache-miss-storm traffic produced a 0.00% observed KV hit rate and 3.955s p95
  request latency on the same serving profile.
- Long-context traffic completed 599/599 requests with observed KV metrics,
  14.58 GB observed GPU memory usage, 90.58% observed average GPU utilization,
  and 1.918s p95 request latency.
- Evictions, reloads, and per-request physical block ownership remain
  unavailable in these live reports.

## Promotion Gates

| Gate | Requirement |
| --- | --- |
| Modern serving target | Passed: `modern-vllm-0221-prefix` ran `vllm/vllm-openai:v0.22.1` and exposed vLLM metrics. |
| Hit/miss contrast | Passed: `shared-system-prompt` reported 97.25% observed KV hit rate; `cache-miss-storm` reported 0.00%. |
| Pressure diagnosis | Passed for utilization/latency correlation: `long-context-workload` reported observed KV utilization, queue, prefill, decode, GPU memory, and tail latency. |
| Trace clarity | Request A/B/C timeline artifacts identify observed versus derived block events. |

## Evidence Boundaries

- Do not mix historical `experiments/kv-cache` vLLM `0.9.0` conclusions into
  this result page unless the table explicitly labels them as historical.
- Per-request physical block ownership is evidence only when the run includes
  vLLM KV events or an explicit observatory trace.
- Missing KV block, eviction, or reload metrics must remain `n/a` or `null`;
  they should not be inferred from latency alone.

## Planned Graphs

- Request A/B/C KV block allocation over time using a `kv-cache-trace/v1`
  artifact
- prefix-cache hit tokens versus miss tokens from the promoted reports
- KV utilization versus p95 queue, prefill, and decode latency from the
  promoted reports
- evictions and reloads over the run window when available
