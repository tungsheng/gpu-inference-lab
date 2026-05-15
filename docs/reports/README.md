# Reports

`./scripts/evaluate`, `./scripts/experiment run`, and
`./scripts/experiment run-stream` write generated Markdown and JSON artifacts
here. Generated reports are ignored by Git.

Keep curated cross-experiment conclusions in `docs/evidence.md` and
per-experiment conclusions in `experiments/<name>/results.md`.

## Schemas

| Producer | Schema |
| --- | --- |
| `./scripts/evaluate` | `evaluate-report/v1` |
| `./scripts/experiment` | `experiment-report/v1` |

## Evaluation Reports

Evaluation reports capture one burst run, a policy comparison, or an
active-pressure target sweep. Key fields:

- profile, policy, resilience mode, HPA metric, and target
- metric collection status and reason
- first and second GPU node timing
- first public response, HPA scale-out, second Ready replica, scale-in, and
  cleanup timing
- interruption and recovery timing for synthetic interruption drills
- p95 latency, derived queue wait, TTFT, queue pressure, throughput, GPU
  utilization, NodeClaim count, and estimated serving GPU cost when available

If final Prometheus or DCGM collection fails after workload cleanup,
`./scripts/evaluate` still writes a partial report. Kubernetes
timeline, cost, and resilience fields are preserved; missing Prometheus-derived
fields appear as `n/a` in Markdown and `null` in JSON.

## Experiment Reports

Experiment reports capture one case/profile pair. Use the JSON for
programmatic comparison and the Markdown for operator readout.

The helper below summarizes the latest artifact for each case/profile pair:

```bash
./scripts/experiment summarize-reports --experiment kv-cache
```

The summary includes offered work, unserved work, delivery ratio,
dropped/interrupted work, tail latency, throughput, queue pressure, and GPU
fields when present in source JSON.

## Artifact Rules

- Do not commit routine generated reports.
- Force-add a generated report only when it belongs in the project narrative.
- Promote stable conclusions into curated docs instead of linking every local
  run.
- Store derived comparison visuals under the owning experiment's `graphs/`
  directory, not under `docs/reports/`.
- Treat reports with missing GPU, queue, cost, or accuracy fields as partial
  evidence for those topics.
