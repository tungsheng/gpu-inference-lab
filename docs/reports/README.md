# Reports

`./scripts/evaluate` writes experiment artifacts into this directory.

Each evaluation run can produce:

- a Markdown summary report and JSON document for a single policy run
- or, in compare mode, two per-policy artifacts plus a compare summary pair

## Profiles

The script currently supports profiles:

- `zero-idle`
- `warm-1`

And policies:

- `running`
- `active-pressure`
- `compare`

## What The Reports Capture

The report format is designed to summarize one burst experiment or compare two
policies on the same profile:

- selected policy, HPA metric name, and HPA target average value
- first and second GPU node timing
- first public response timing
- HPA scale-out timing
- second Ready replica timing
- scale-in and final cleanup timing
- p95 request latency and p95 time to first token as the queue/TTFT proxy
- peak waiting requests and peak active requests
- generation throughput
- average and max GPU utilization
- peak active serving `NodeClaim` count
- estimated serving GPU cost, split by capacity type when possible
- compare reports with side-by-side latency, queue proxy, GPU utilization,
  NodeClaim, second-replica, and burst-cost rows

## How To Use Them

Use the Markdown report for a quick operator readout and the JSON report when
you want to compare runs programmatically.

The checked-in report files in this directory are historical run artifacts, not
the source of truth for the repo's current behavior. The scripts and manifests
remain the source of truth.

## Important Limitation

Current reports compare two real HPA policies, but queue depth is still
represented indirectly through p95 TTFT plus peak waiting requests rather than a
dedicated queue-wait histogram.
