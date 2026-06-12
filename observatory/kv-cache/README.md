# KV Cache Observatory

This module contains local tooling for making KV cache behavior visible in
`gpu-inference-lab`.

## Trace Contract

Trace artifacts use `kv-cache-trace/v1`. A trace contains run metadata, request
labels, block metadata, and timestamped events such as allocation, reuse, free,
and eviction.

## Commands

```bash
./scripts/kv-observe demo --output /tmp/kv-cache-observatory.html
./scripts/kv-observe render --input trace.json --output trace.html
./scripts/kv-observe collect --prometheus-url http://127.0.0.1:9090 --output kv-summary.json
./scripts/kv-observe preflight --experiment kv-cache-observatory --profile modern-vllm-0221
```

The demo path is intentionally local-only so the article and visual language can
be developed without an AWS cluster.
