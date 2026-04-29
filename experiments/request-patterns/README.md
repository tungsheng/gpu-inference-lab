# Request Pattern Utilization

## Goal

Show how traffic shape and request-size variance affect useful GPU work even
when the serving stack is healthy.

## Cases

| Case | Shape | Purpose |
| --- | --- | --- |
| `steady-small` | steady homogeneous 512/128 requests | baseline utilization and latency |
| `burst-small` | fast ramp to higher arrival rate | queueing and p99 latency under burst pressure |
| `uneven-size-mix` | weighted short/medium/long request mix | scheduler behavior when request sizes differ |
| `spike-to-zero` | rapid spike followed by traffic drop | warmup, cooldown, and idle-capacity behavior |

`uneven-size-mix` uses `request-shapes.csv` to choose short, medium, and long
requests by weight during one k6 job.

## Commands

Render a mixed load job:

```bash
./scripts/experiment render-load \
  --experiment request-patterns \
  --case uneven-size-mix \
  --output /tmp/request-patterns-uneven-size-mix.yaml
```

Live run after `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment request-patterns \
  --case steady-small \
  --profile default
```

Run all four cases with the same serving profile before changing scheduler,
HPA, or capacity settings.

## Readout

Compare p50/p95/p99 latency, completed requests/sec, generated tokens/sec, peak
waiting/running/active requests, GPU utilization, and latency split by
`request_shape` for the uneven-size case.
