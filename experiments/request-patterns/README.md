# Request Pattern Utilization

## Goal

Explain why GPUs can be underutilized even when the serving stack is healthy:
traffic shape, request-size variance, queueing, and scheduler behavior all
change how much useful work reaches the GPU over time.

## Cases

| Case | Shape | Purpose |
| --- | --- | --- |
| `steady-small` | steady homogeneous 512/128 requests | baseline utilization and latency |
| `burst-small` | fast ramp to higher arrival rate | queueing and p99 latency under burst pressure |
| `uneven-size-mix` | weighted short/medium/long request mix | scheduler behavior when request sizes differ |
| `spike-to-zero` | rapid spike followed by traffic drop | warmup, cooldown, and idle-capacity behavior |

The `uneven-size-mix` case uses `request-shapes.csv` so one k6 job sends a
weighted mix:

| Shape | Prompt token target | Output token cap | Weight |
| --- | ---: | ---: | ---: |
| `short` | 128 | 64 | 6 |
| `medium` | 512 | 128 | 3 |
| `long` | 1536 | 512 | 1 |

## Render A Mixed Load Job

```bash
./scripts/experiment render-load \
  --experiment request-patterns \
  --case uneven-size-mix \
  --output /tmp/request-patterns-uneven-size-mix.yaml
```

The generated k6 script chooses a request shape per iteration and tags the
request with `request_shape`, which lets later Prometheus or k6 analysis split
latency by short, medium, and long requests.

## Run One Live Case

`run` requires a configured Kubernetes context and a live cluster from
`./scripts/up`.

```bash
./scripts/up

./scripts/experiment run \
  --experiment request-patterns \
  --case steady-small \
  --profile default
```

Run all four cases with the same `default` profile before changing scheduler,
HPA, or capacity settings. That keeps the traffic pattern as the controlled
variable.

## Metrics To Capture

- p50, p95, and p99 request latency
- completed requests/sec and generated tokens/sec
- peak waiting, running, and active requests
- average and max GPU utilization
- GPU memory used and free
- latency split by `request_shape` for the uneven-size case

## Expected Interpretation

Steady traffic should produce the cleanest utilization baseline. Burst and
spike-to-zero traffic should show queue buildup, cooldown gaps, and idle
periods. Uneven-size traffic should show that short requests can wait behind
longer prefill/decode work, which can increase tail latency even when aggregate
request rate looks moderate.
