# Reports

`./scripts/evaluate` writes experiment artifacts into this directory.

Each evaluation run can produce:

- a Markdown summary report
- a JSON document with the same core fields for downstream processing

## Profiles

The script currently supports:

- `zero-idle`
- `warm-1`

## What The Reports Capture

The report format is designed to summarize one burst experiment:

- first and second GPU node timing
- first public response timing
- HPA scale-out timing
- second Ready replica timing
- scale-in and final cleanup timing
- p95 request latency and p95 time to first token
- generation throughput
- average and max GPU utilization
- peak active serving `NodeClaim` count
- estimated serving GPU cost, split by capacity type when possible

## How To Use Them

Use the Markdown report for a quick operator readout and the JSON report when
you want to compare runs programmatically.

The checked-in report files in this directory are historical run artifacts, not
the source of truth for the repo's current behavior. The scripts and manifests
remain the source of truth.

## Important Limitation

Current reports reflect the current HPA policy, which scales from
`vllm_requests_running`. They are a strong baseline for future comparisons once
the repo adds a capacity-aware autoscaling signal.
