# Batching Scheduler Tradeoffs

## Goal

Measure the throughput and tail-latency tradeoff created by vLLM scheduler
settings under the same request shape.

This experiment does not claim vLLM has a true "no batching" mode. The
constrained profile only limits active sequences and batched-token budget.

## Cases

| Case | Prompt token target | Output token cap | Traffic shape |
| --- | ---: | ---: | --- |
| `steady-512-output-128` | 512 | 128 | steady homogeneous requests |
| `burst-512-output-128` | 512 | 128 | burst traffic with higher p99 pressure |

## Serving Profiles

| Profile | Scheduler settings | Purpose |
| --- | --- | --- |
| `constrained-scheduler` | `--max-num-seqs 1`, `--max-num-batched-tokens 2048` | lower-concurrency reference point |
| `limited-batching` | `--max-num-seqs 8`, `--max-num-batched-tokens 4096` | explicit moderate batching |
| `dynamic-default` | vLLM defaults | repo baseline with no explicit scheduler caps |

## Commands

Render a serving profile:

```bash
./scripts/experiment render-serving \
  --experiment batching \
  --profile constrained-scheduler \
  --output /tmp/vllm-batching-constrained.yaml
```

Live run after `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment batching \
  --case steady-512-output-128 \
  --profile dynamic-default
```

Run the same case across all three profiles before changing workload shape.

## Readout

Compare completed requests/sec, generated tokens/sec, p50/p95/p99 latency, and
failures. GPU utilization, memory pressure, and serving-side TTFT should be
read when Prometheus/DCGM rollups are available.
