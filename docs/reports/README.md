# Reports

`./scripts/evaluate`, `./scripts/experiment run`, and
`./scripts/experiment run-stream` write generated artifacts into this directory
by default. Generated report files are intentionally ignored by Git; keep
curated conclusions in `docs/experiments-summary.md` or
`experiments/<name>/results.md`.

Each evaluation run can produce:

- a Markdown summary report and JSON document for a single policy run
- or, in compare mode, two per-policy artifacts plus a compare summary pair
- or, in sweep mode, one per-target artifact pair plus a sweep summary pair

`./scripts/evaluate` JSON artifacts use `schema_version:
evaluate-report/v1`. `./scripts/experiment` artifacts use
`experiment-report/v1`.

## Profiles

The script currently supports profiles:

- `zero-idle`
- `warm-1`

And policies:

- `running`
- `active-pressure`
- `compare`
- `sweep`

And resilience modes:

- `healthy`
- `spot-unavailable`
- `spot-interruption`

## What The Reports Capture

The report format is designed to summarize one burst experiment, compare two
policies on the same profile, or sweep multiple active-pressure targets:

- resilience mode plus the resulting burst-capacity outcome
- selected policy, HPA metric name, and HPA target average value
- metric collection status and reason, so a late Prometheus/DCGM outage is
  visible as `partial` instead of being confused with a full metrics run
- first and second GPU node timing
- first, second, and recovery GPU availability zones
- first public response timing
- HPA scale-out timing
- second Ready replica timing
- interruption trigger timing plus recovery timing when the live interruption
  drill is used
- scale-in and final cleanup timing
- p95 request latency, p95 estimated queue wait, and p95 time to first token
- peak waiting requests and peak active requests
- peak active requests per active GPU node
- generation throughput
- average and max GPU utilization, plus average headroom
- peak active serving `NodeClaim` count
- estimated serving GPU cost, split by capacity type when possible
- compare reports with side-by-side latency, queue wait, TTFT, GPU
  utilization, NodeClaim, second-replica, interruption-recovery, and
  burst-cost rows
- sweep reports with per-target status, latency, queue wait, TTFT, GPU
  utilization, NodeClaim, interruption-recovery, burst-cost rows, and a
  recommended target

## How To Use Them

Use the Markdown report for a quick operator readout and the JSON report when
you want to compare runs programmatically. The sweep summary is the fastest
way to review whether one `--active-target` looks clearly healthier than the
others for the same burst shape.

For experiment reports, use the built-in summary table to compare the latest
artifact for each case/profile pair:

```bash
./scripts/experiment summarize-reports --experiment kv-cache
```

The experiment summary includes offered iterations, unserved iterations,
delivery ratio, dropped/interrupted iterations, tail latency, request throughput,
queue pressure, and GPU utilization when those fields are present in the source
JSON.

If final Prometheus or DCGM collection fails after the workload has already
cleaned up, `./scripts/evaluate` still writes the report with
`metrics_collection_status: partial`. Timeline, cost, and resilience fields are
preserved from Kubernetes observations, while unavailable Prometheus-derived
metrics are written as `n/a` in Markdown and `null` in JSON.

The checked-in source of truth is the report contract plus curated summaries,
not every local run output. Force-add a specific generated report only when it
is intentionally part of the project narrative.

## Important Limitation

Current reports compare real HPA policies and can sweep active-pressure
targets, and they now derive queue wait from waiting depth over request
completion rate, but they still do not expose a dedicated queue-wait
histogram. The current interruption drill is still synthetic: it deletes the
live burst `NodeClaim` and withdraws the spot `NodePool`, rather than
consuming a cloud-native interruption signal.
