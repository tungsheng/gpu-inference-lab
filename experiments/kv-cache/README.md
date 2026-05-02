# KV Cache Vs Concurrency

## Goal

Show how longer prompts increase KV-cache pressure and reduce the stable
concurrency a single serving profile can support.

## Cases

| Case | Prompt token target | Output token cap | Initial target rate |
| --- | ---: | ---: | ---: |
| `prompt-512-output-100` | 512 | 100 | 6 req/s |
| `prompt-2048-output-200` | 2048 | 200 | 4 req/s |
| `prompt-8192-output-300` | 8192 | 300 | 2 req/s |

The prompt generator uses repeated English words as approximate token targets.
Tokenizer-backed prompt construction is still future work.

## Serving Profiles

| Profile | Use it for |
| --- | --- |
| `default` | cases that fit the checked-in 2048-token vLLM profile |
| `long-context` | all cases in the comparable KV-cache result matrix |

## Commands

Local render:

```bash
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-load.yaml
```

Measured live-cluster run after `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile long-context
```

Use `default` only for smoke checks that fit the checked-in 2048-token profile.
Use `long-context` when building the KV-cache comparison, including the
8192-token prompt case:

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-8192-output-300 \
  --profile long-context
```

## Readout

Compare request failures, p95/p99 latency, generated tokens/sec, GPU memory,
and GPU utilization. The result should explain where longer context shifts the
latency/throughput envelope and whether failures look like serving saturation
or memory pressure. Do not claim KV-cache pressure as the primary constraint
until all three cases have representative reports with GPU memory/utilization
signals.
