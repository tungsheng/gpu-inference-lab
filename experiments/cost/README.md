# Cost Per Useful Work

## Goal

Connect serving behavior to dollars by comparing cost per successful request
and cost per generated token for a constrained serving profile versus a more
concurrent batched profile.

## Cases

| Case | Prompt token target | Output token cap | Traffic shape |
| --- | ---: | ---: | --- |
| `steady-cost-efficiency` | 512 | 128 | steady load for cost-per-request comparison |
| `burst-cost-efficiency` | 512 | 128 | burst load for cost and SLO tradeoffs |

Both cases fit the checked-in 2048-token serving profiles.

## Serving Profiles

| Profile | Scheduler settings | Cost model | Purpose |
| --- | --- | --- | --- |
| `naive-single` | `--max-num-seqs 1`, `--max-num-batched-tokens 2048` | serving GPU only | one-request-at-a-time reference point |
| `optimized-batched` | `--max-num-seqs 32`, `--max-num-batched-tokens 8192` | serving GPU only | higher useful work per GPU |

Both profiles intentionally use the same fixed hourly serving cost. The
experiment is asking how much more useful work the same GPU can produce before
the latency SLO fails.

## Render A Report Scaffold

```bash
./scripts/experiment render-report \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

The scaffold includes the cost scope, hourly serving cost, SLO targets, and
empty result fields. Live runs fill successful requests, generated tokens,
estimated burst cost, cost per 1K successful requests, cost per 1M generated
tokens, and SLO pass/fail.

## Run One Live Case

`run` requires a configured Kubernetes context and a live cluster from
`./scripts/up`.

```bash
./scripts/up

./scripts/experiment run \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile naive-single

./scripts/experiment run \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

Run the same case against both profiles. Then repeat with
`burst-cost-efficiency` to see whether the lower cost per useful unit still
holds when p99 latency is under pressure.

## Metrics To Capture

- completed requests
- failed requests
- successful requests
- generated tokens from completion usage
- run duration
- p95 and p99 request latency
- SLO pass/fail
- estimated serving burst cost
- cost per 1K successful requests
- cost per 1M generated tokens
- GPU utilization once Prometheus/DCGM rollups are added

## Expected Interpretation

The optimized profile should lower cost per useful request and cost per
generated token when the additional concurrency turns into successful work. If
tail latency crosses the SLO, the cheaper profile is not automatically better:
the useful-work metric must be read beside p95/p99 latency and failures.
