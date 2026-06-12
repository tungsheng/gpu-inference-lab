# KV Cache Observatory: Diagnosing Memory Pressure And Latency In LLM Serving

KV cache is one of the most discussed parts of LLM serving and one of the
least visible during everyday operations. Teams often know that long prompts,
shared system messages, and agent loops change memory pressure, but they only
see the symptoms: queueing, worse time to first token, lower throughput, or GPU
memory near the edge.

KV Cache Observatory makes those symptoms measurable inside this lab.

## Live vLLM 0.22.1 Snapshot

These runs were produced on June 12, 2026 with the
`modern-vllm-0221-prefix` serving profile and
`vllm/vllm-openai:v0.22.1`. KV cache fields below are marked `observed`
because they came from vLLM/Prometheus metrics in the experiment reports.

| Case | Source report | Successful requests | p95 latency | p95 queue | p95 prefill | p95 decode | KV hit rate | KV utilization | GPU memory |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Shared system prompt | [JSON](../reports/experiment-kv-cache-observatory-shared-system-prompt-modern-vllm-0221-prefix-20260612-142711.json) | 1259/1259 | 1.229s | 0.285s | 0.285s | 1.475s | 97.25% observed | 0.289% observed | 14.42 GB observed |
| Cache miss storm | [JSON](../reports/experiment-kv-cache-observatory-cache-miss-storm-modern-vllm-0221-prefix-20260612-143551.json) | 1259/1259 | 3.955s | 0.285s | 0.285s | 4.860s | 0.00% observed | 3.779% observed | 14.42 GB observed |
| Long-context workload | [JSON](../reports/experiment-kv-cache-observatory-long-context-workload-modern-vllm-0221-prefix-20260612-144914.json) | 599/599 | 1.918s | 0.285s | 0.285s | 1.975s | 99.64% observed | 0.734% observed | 14.58 GB observed |

The strongest current result is the controlled contrast between shared-prefix
traffic and miss-storm traffic. With the same vLLM image and serving profile,
the shared-system-prompt run reported a 97.25% observed KV hit rate and 1.229s
p95 request latency. The miss-storm run reported a 0.00% observed KV hit rate
and 3.955s p95 request latency. That is the observatory's core diagnostic
story: cache behavior is visible in the report, and the latency difference is
large enough to explain operational symptoms without guessing.

The long-context workload adds a pressure point for the article. It completed
599/599 requests with observed KV metrics, 14.58 GB observed GPU memory usage,
90.58% observed average GPU utilization, and 1.918s p95 request latency.
This run did not produce an eviction or reload signal; those fields remain
`unavailable` in the report and should not be claimed as observed behavior.

## What The Observatory Measures

The vLLM `0.22.1` path is the default target for this initiative. The repo keeps
older `0.9.0` KV-cache results as historical evidence, but new observatory
claims should be produced with the `modern-vllm-0221` serving profile.

The observatory separates three evidence classes:

| Source | Meaning |
| --- | --- |
| observed | Reported directly by vLLM, Prometheus, DCGM, or KV events. |
| derived | Computed from observed counters, configured block counts, or an explicit trace artifact. |
| unavailable | Not exposed by the current run; left as `null` or `n/a`. |

That distinction matters. KV utilization and prefix-cache hit tokens can be
observed from vLLM metrics when present. Per-request physical block ownership
requires KV events or an explicit trace; it should not be inferred from latency
alone.

## Experiment 1: Long-Context Workload

The long-context case reuses the existing `8192/300` pressure story, but moves
the measurement target to vLLM `0.22.1`. The goal is not just to find the
latency knee. The goal is to show whether rising KV utilization lines up with
queue delay, prefill time, decode time, and GPU memory pressure.

Live report:
[experiment-kv-cache-observatory-long-context-workload-modern-vllm-0221-prefix-20260612-144914.json](../reports/experiment-kv-cache-observatory-long-context-workload-modern-vllm-0221-prefix-20260612-144914.json).

Observed result: the run completed 599/599 requests with 1.918s p95 request
latency, 1.975s p95 decode time, 0.734% KV utilization, and 14.58 GB GPU memory
used. Prefix-cache hits were observed at 99.64%, which means this particular
pressure case is useful for long-context memory and decode cost, but not for
eviction/reload analysis.

Promotion gate: the report must include p95 queue, prefill, decode, KV
utilization, GPU memory, and request delivery metrics.

## Experiment 2: Shared System Prompt

This case sends Request A, Request B, and Request C with a large shared prefix
and request-specific suffixes. A healthy prefix-cache path should report higher
hit tokens and a better hit rate than the miss-storm case.

Live report:
[experiment-kv-cache-observatory-shared-system-prompt-modern-vllm-0221-prefix-20260612-142711.json](../reports/experiment-kv-cache-observatory-shared-system-prompt-modern-vllm-0221-prefix-20260612-142711.json).

Observed result: the run completed 1259/1259 requests with a 97.25% KV hit rate
and 1.229s p95 request latency. Compared with the cache miss storm, this run
kept p95 decode at 1.475s instead of 4.860s while preserving the same request
success count.

The timeline artifact should show the shared prefix as reused blocks and the
suffix as new allocation.

## Experiment 3: Agent Workflow

Agent-style traffic repeats system instructions, tool schemas, recent
observations, and scratchpad state. This workload is meant to make partial reuse
visible across chained requests rather than only across identical prompts.

The useful readout is the relationship between reuse, TTFT, and prefill time.
If reuse is real, prefill pressure should fall relative to similarly sized
miss-heavy requests.

## Experiment 4: Cache Miss Storm

The miss-storm case intentionally changes the early prefix for each request.
Because block hashes chain from the beginning of the prompt, changing the early
prefix should defeat reuse for the later repeated suffix too.

Live report:
[experiment-kv-cache-observatory-cache-miss-storm-modern-vllm-0221-prefix-20260612-143551.json](../reports/experiment-kv-cache-observatory-cache-miss-storm-modern-vllm-0221-prefix-20260612-143551.json).

Observed result: the run completed 1259/1259 requests with a 0.00% KV hit rate
and 3.955s p95 request latency. This is the clean contrast for the shared-system
prompt case: the miss storm did not reuse prefix cache, and p95 decode expanded
to 4.860s.

This is the contrast case for shared system prompts. It should show low
prefix-cache hit rate, higher prefill pressure, and clearer memory churn.

## Visual Artifact

The local renderer creates a Request A/B/C block timeline:

```bash
./scripts/kv-observe demo --output /tmp/kv-cache-observatory.html
```

The generated trace uses `kv-cache-trace/v1`. Article figures should link to
the trace or report that generated them. When a timeline is derived rather than
directly observed from vLLM KV events, the figure caption should say so.

## First Run Sequence

```bash
./scripts/kv-observe preflight \
  --experiment kv-cache-observatory \
  --profile modern-vllm-0221

./scripts/experiment run \
  --experiment kv-cache-observatory \
  --case shared-system-prompt \
  --profile modern-vllm-0221-prefix

./scripts/experiment run \
  --experiment kv-cache-observatory \
  --case cache-miss-storm \
  --profile modern-vllm-0221-prefix

./scripts/experiment run \
  --experiment kv-cache-observatory \
  --case long-context-workload \
  --profile modern-vllm-0221-prefix
```

## Article Standard

Every promoted chart needs a source report or trace. Every KV claim needs a
source label: observed, derived, or unavailable. That is the difference between
"we think KV cache caused this" and "we can show the memory and latency path."
