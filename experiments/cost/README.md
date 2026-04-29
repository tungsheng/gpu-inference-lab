# Cost Per Useful Work

## Goal

Compare cost per successful request and generated token for constrained versus
more concurrent/batched serving profiles.

## Cases

| Case | Prompt token target | Output token cap | Traffic shape |
| --- | ---: | ---: | --- |
| `steady-cost-efficiency` | 512 | 128 | steady load for cost-per-request comparison |
| `burst-cost-efficiency` | 512 | 128 | burst load for cost and SLO tradeoffs |

## Serving Profiles

| Profile | Scheduler settings | Purpose |
| --- | --- | --- |
| `naive-single` | `--max-num-seqs 1`, `--max-num-batched-tokens 2048` | one-request-at-a-time reference point |
| `optimized-batched` | `--max-num-seqs 32`, `--max-num-batched-tokens 8192` | higher useful work per GPU |

Both profiles use the same fixed serving-GPU hourly cost. The experiment asks
how much useful work the same GPU can produce before latency or failures cross
the SLO.

## Commands

Render a report scaffold:

```bash
./scripts/experiment render-report \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

Measured live-cluster runs after `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile naive-single

./scripts/experiment run \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

## Readout

Compare successful requests, failed requests, generated tokens, run duration,
p95/p99 latency, estimated serving burst cost, cost per 1K successful requests,
cost per 1M generated tokens, and SLO pass/fail.
