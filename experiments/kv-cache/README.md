# KV Cache Vs Concurrency

## Goal

Show how longer prompts increase KV-cache pressure and reduce the stable
concurrency a single serving profile can support.

## Cases

| Case | Prompt token target | Output token cap | Initial target rate |
| --- | ---: | ---: | ---: |
| `prompt-512-output-100` | 512 | 100 | 6 req/s |
| `prompt-2048-output-200` | 2048 | 200 | 4 req/s |
| `prompt-8192-output-300-rate-010` | 8192 | 300 | 0.10 req/s |
| `prompt-8192-output-300-rate-015` | 8192 | 300 | 0.15 req/s |
| `prompt-8192-output-300-rate-020` | 8192 | 300 | 0.20 req/s |
| `prompt-8192-output-300-rate-025` | 8192 | 300 | 0.25 req/s |
| `prompt-8192-output-300-rate-050` | 8192 | 300 | 0.50 req/s |
| `prompt-8192-output-300-rate-075` | 8192 | 300 | 0.75 req/s |
| `prompt-8192-output-300-rate-100` | 8192 | 300 | 1.00 req/s |
| `prompt-8192-output-300-rate-105` | 8192 | 300 | 1.05 req/s |
| `prompt-8192-output-300-rate-110` plus `-r2`/`-r3` | 8192 | 300 | 1.10 req/s |
| `prompt-8192-output-300-rate-115` plus `-r2`/`-r3` | 8192 | 300 | 1.15 req/s |
| `prompt-8192-output-300-rate-120` plus `-r2`/`-r3` | 8192 | 300 | 1.20 req/s |
| `prompt-8192-output-300-rate-125` | 8192 | 300 | 1.25 req/s |
| `prompt-8192-output-300-rate-125-admission-032` | 8192 | 300 | 1.25 req/s |
| `prompt-8192-output-300-rate-150` | 8192 | 300 | 1.50 req/s |
| `prompt-8192-output-300` | 8192 | 300 | 2 req/s |

The low-rate 8192-token cases are a stability sweep. Run them before treating
the 2 req/s case as anything more than a saturation probe. The `1.05` through
`1.20` req/s cases narrow the observed knee between the stable `1.00` req/s run
and the saturated `1.25` req/s run. The repeated `1.10`, `1.15`, and `1.20`
cases capture run-to-run variance near that knee. The `admission-032` case caps
k6 VUs at the serving profile's sequence limit so overload is reported as
explicit unmet demand instead of only as very long tail latency. The prompt
generator uses a repeated common English word as an approximate token target.
Tokenizer-backed prompt construction is still future work, so report
conclusions should continue to reference measured behavior rather than exact
tokenizer counts.

## Serving Profiles

| Profile | Use it for |
| --- | --- |
| `default` | cases that fit the checked-in 2048-token vLLM profile |
| `long-context` | all cases in the comparable KV-cache result matrix |
| `long-context-seqs-16` | conservative scheduler variant that trades concurrency for lower tail latency |
| `long-context-seqs-24` | midpoint scheduler variant for the saturation knee |
| `long-context-batched-16384` | batched-token capacity probe for long prefill throughput |

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
  --case prompt-8192-output-300-rate-010 \
  --profile long-context
```

Then step through `rate-015`, `rate-020`, `rate-025`, `rate-050`, `rate-075`,
`rate-100`, `rate-105`, `rate-110`, `rate-115`, `rate-120`, `rate-125`, and
`rate-150`. Repeat the knee cases with the `-r2` and `-r3` rows before choosing
a stable boundary. Treat the highest case with zero failed requests, zero dropped
iterations, zero interrupted iterations, high delivery ratio, and bounded waiting
pressure as the current stable long-context rate.

After runs, summarize the latest report per case/profile:

```bash
./scripts/experiment summarize-reports --experiment kv-cache
```

## Readout

Compare request failures, offered iterations, unserved iterations, delivery
ratio, dropped iterations, interrupted iterations, p95/p99 latency, generated
tokens/sec, waiting/running/active request pressure, GPU memory, and GPU
utilization. The result should explain where longer context shifts the
latency/throughput envelope and whether failures look like client queue
saturation, scheduler saturation, admission-control shedding, or memory
pressure.
