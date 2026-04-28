# Batching Scheduler Tradeoffs

## Goal

Measure the throughput and tail-latency tradeoff created by vLLM scheduler
settings under the same request shape.

This experiment does not claim there is a true vLLM "no batching" mode. vLLM
still schedules requests internally; the constrained profile simply limits the
number of active sequences and the batched-token budget so the behavior is
easier to compare against less restrictive scheduler profiles.

## Cases

| Case | Prompt token target | Output token cap | Traffic shape |
| --- | ---: | ---: | --- |
| `steady-512-output-128` | 512 | 128 | steady homogeneous requests |
| `burst-512-output-128` | 512 | 128 | burst traffic with higher p99 pressure |

Both cases fit the 2048-token serving profiles.

## Serving Profiles

| Profile | Scheduler settings | Purpose |
| --- | --- | --- |
| `constrained-scheduler` | `--max-num-seqs 1`, `--max-num-batched-tokens 2048` | lower concurrency reference point |
| `limited-batching` | `--max-num-seqs 8`, `--max-num-batched-tokens 4096` | explicit moderate batching |
| `dynamic-default` | vLLM defaults | unconstrained scheduler baseline for this repo |

## Render A Serving Profile

```bash
./scripts/experiment render-serving \
  --experiment batching \
  --profile constrained-scheduler \
  --output /tmp/vllm-batching-constrained.yaml
```

Render the default-dynamic profile to compare the absence of explicit
`--max-num-seqs` and `--max-num-batched-tokens` flags:

```bash
./scripts/experiment render-serving \
  --experiment batching \
  --profile dynamic-default \
  --output /tmp/vllm-batching-dynamic-default.yaml
```

## Run One Live Case

`run` requires a configured Kubernetes context and a live cluster from
`./scripts/up`.

```bash
./scripts/up

./scripts/experiment run \
  --experiment batching \
  --case steady-512-output-128 \
  --profile dynamic-default
```

Run the same case across all three profiles, then compare requests/sec, p95/p99
latency, generation tokens/sec when the response usage field is available, and
GPU utilization once Prometheus/DCGM rollups are added.

## Metrics To Capture

- completed requests/sec
- generated tokens/sec from completion usage when vLLM returns it
- p50, p95, and p99 end-to-end latency
- p50 and p95 TTFT from streaming or Prometheus follow-up instrumentation
- GPU utilization and memory pressure from Prometheus/DCGM
- queue depth and active-request peaks from vLLM metrics

## Expected Interpretation

The constrained scheduler profile should provide a lower-concurrency reference
point with lower batching efficiency. The limited and dynamic profiles should
increase throughput by allowing more work to be combined, while burst workloads
may show higher p99 latency because more requests can wait behind active batch
work.
