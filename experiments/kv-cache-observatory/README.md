# KV Cache Observatory

## Goal

Make KV cache behavior visible in modern vLLM serving. This experiment family
uses `vllm/vllm-openai:v0.22.1` as the default modern target and keeps older
`v0.9.0` KV-cache evidence as historical comparison only.

## Cases

| Case | Purpose |
| --- | --- |
| `long-context-workload` | Correlate KV utilization with queue, prefill, decode, and tail latency under long-context pressure. |
| `shared-system-prompt` | Make prefix-cache hits visible when requests share a large system prompt. |
| `agent-workflow` | Show repeated system, tool, and scratchpad context across chained agent-like requests. |
| `cache-miss-storm` | Defeat prefix reuse with randomized prefixes and expose miss-heavy pressure. |

## Commands

Local observatory demo:

```bash
./scripts/kv-observe demo --output /tmp/kv-cache-observatory.html
```

Render the modern serving manifest:

```bash
./scripts/experiment render-serving \
  --experiment kv-cache-observatory \
  --profile modern-vllm-0221 \
  --output /tmp/vllm-0221.yaml
```

Run a live case after `./scripts/up`:

```bash
./scripts/kv-observe preflight \
  --experiment kv-cache-observatory \
  --profile modern-vllm-0221

./scripts/experiment run \
  --experiment kv-cache-observatory \
  --case shared-system-prompt \
  --profile modern-vllm-0221-prefix
```

## Readout

Compare KV cache utilization, prefix-cache hit and miss tokens, active/free
block counts when available, evictions/reloads when exposed by vLLM events or
future metrics, queue/prefill/decode latency, GPU memory, and delivery ratio.
Every promoted result should label each KV signal as observed, derived, or
unavailable.
