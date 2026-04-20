# Reports

`./scripts/evaluate` writes experiment artifacts into this directory.

Each evaluation run can produce:

- a Markdown summary report and JSON document for a single policy run
- or, in compare mode, two per-policy artifacts plus a compare summary pair
- or, in sweep mode, one per-target artifact pair plus a sweep summary pair

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

## What The Reports Capture

The report format is designed to summarize one burst experiment, compare two
policies on the same profile, or sweep multiple active-pressure targets:

- resilience mode plus the resulting burst-capacity outcome
- selected policy, HPA metric name, and HPA target average value
- first and second GPU node timing
- first and second GPU availability zones
- first public response timing
- HPA scale-out timing
- second Ready replica timing
- scale-in and final cleanup timing
- p95 request latency, p95 estimated queue wait, and p95 time to first token
- peak waiting requests and peak active requests
- peak active requests per active GPU node
- generation throughput
- average and max GPU utilization, plus average headroom
- peak active serving `NodeClaim` count
- estimated serving GPU cost, split by capacity type when possible
- compare reports with side-by-side latency, queue wait, TTFT, GPU
  utilization, NodeClaim, second-replica, and burst-cost rows
- sweep reports with per-target status, latency, queue wait, TTFT, GPU
  utilization, NodeClaim, burst-cost rows, and a recommended target

## How To Use Them

Use the Markdown report for a quick operator readout and the JSON report when
you want to compare runs programmatically. The sweep summary is the fastest
way to review whether one `--active-target` looks clearly healthier than the
others for the same burst shape.

The checked-in report files in this directory are historical run artifacts, not
the source of truth for the repo's current behavior. The scripts and manifests
remain the source of truth.

## Important Limitation

Current reports compare real HPA policies and can sweep active-pressure
targets, and they now derive queue wait from waiting depth over request
completion rate, but they still do not expose a dedicated queue-wait
histogram. The current resilience experiment simulates spot scarcity by
withdrawing the spot `NodePool` before the burst; it does not yet inject a live
spot interruption after the second node is already serving.
