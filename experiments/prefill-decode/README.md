# Prefill Vs Decode Timing

## Goal

Separate prompt-processing pressure from token-generation pressure by comparing
long-prompt/short-output and short-prompt/long-output requests.

## Cases

| Case | Prompt token target | Output token cap | Expected pressure |
| --- | ---: | ---: | --- |
| `prefill-heavy` | 1536 | 64 | higher TTFT from prompt processing |
| `decode-heavy` | 128 | 768 | longer decode path and inter-token timing |

Both cases fit the default 2048-token serving profile.

## Commands

Render a streaming client:

```bash
./scripts/experiment render-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --samples 5 \
  --output /tmp/prefill-heavy-stream.yaml
```

Live run after `./scripts/up`:

```bash
./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --profile default \
  --samples 5
```

Run both cases with the same profile before changing serving settings.

## Readout

Compare p50/p95 TTFT, p50/p95 inter-token latency, total request latency, and
streamed chunk throughput. GPU utilization rollups remain future reporting
work for this experiment.
