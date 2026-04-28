# Prefill Vs Decode Timing

## Goal

Measure how long-prompt/short-output and short-prompt/long-output requests
shift latency between prefill and decode.

## Cases

| Case | Prompt token target | Output token cap | Expected pressure |
| --- | ---: | ---: | --- |
| `prefill-heavy` | 1536 | 64 | higher TTFT from prompt processing |
| `decode-heavy` | 128 | 768 | longer decode path and inter-token timing |

Both cases fit the default 2048-token serving profile.

## Render A Streaming Client

```bash
./scripts/experiment render-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --samples 5 \
  --output /tmp/prefill-heavy-stream.yaml
```

The streaming client records client-side TTFT, inter-token latency, total
request latency, and streamed chunk throughput.

## Run One Streaming Case

`run-stream` requires a configured Kubernetes context and a live cluster from
`./scripts/up`.

```bash
./scripts/up

./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --profile default \
  --samples 5
```

Run the decode-heavy case with the same serving profile and compare p50/p95
TTFT with p50/p95 inter-token latency.

```bash
./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case decode-heavy \
  --profile default \
  --samples 5
```

## Metrics To Capture

- p50 and p95 time to first token
- p50 and p95 inter-token latency
- p95 and p99 end-to-end request latency
- streamed chunk throughput
- GPU utilization from Prometheus/DCGM in a future collection slice

## Expected Interpretation

The prefill-heavy case should emphasize time to first token because vLLM must
process more prompt context before streaming begins. The decode-heavy case
should emphasize generation duration and inter-token cadence because more work
happens after the first token is emitted.
