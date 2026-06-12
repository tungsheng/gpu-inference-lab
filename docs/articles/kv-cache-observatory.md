# KV Cache Observatory: Diagnosing Memory Pressure And Latency In LLM Serving

KV cache is one of the most discussed parts of LLM serving and one of the
least visible during everyday operations. Teams often know that long prompts,
shared system messages, and agent loops change memory pressure, but they only
see the symptoms: queueing, worse time to first token, lower throughput, or GPU
memory near the edge.

KV Cache Observatory makes those symptoms measurable inside this lab.

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

Promotion gate: the report must include p95 queue, prefill, decode, KV
utilization, GPU memory, and request delivery metrics.

## Experiment 2: Shared System Prompt

This case sends Request A, Request B, and Request C with a large shared prefix
and request-specific suffixes. A healthy prefix-cache path should report higher
hit tokens and a better hit rate than the miss-storm case.

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
  --profile modern-vllm-0221
```

## Article Standard

Every promoted chart needs a source report or trace. Every KV claim needs a
source label: observed, derived, or unavailable. That is the difference between
"we think KV cache caused this" and "we can show the memory and latency path."
