# Experiments

This directory holds the measured workload contracts behind the decision
engine. Each experiment answers one architecture question and keeps generated
artifacts separate from curated conclusions.

## Directory Contract

| Path | Purpose |
| --- | --- |
| `_profiles/` | shared serving defaults used by experiment-specific profiles |
| `_templates/` | schema and report contracts for experiment metadata |
| `<experiment>/experiment.yaml` | title, question, workload, metrics, and artifact intent |
| `<experiment>/cases.csv` | workload cases and arrival shapes |
| `<experiment>/serving-profiles.csv` | optional vLLM profile overrides |
| `<experiment>/results.md` | curated result matrix, interpretation, graphs, and boundaries |
| `<experiment>/evidence/` | promoted, endpoint-scrubbed report JSON that backs the curated tables; replayable without a cluster |
| `<experiment>/graphs/` | checked-in visuals derived from curated results |

Optional files such as `request-shapes.csv`, `client-policies.csv`,
`cost-profiles.csv`, `accuracy-cases.csv`, `scenarios.csv`,
`mitigations.csv`, `suites.csv`, and `quantization/` appear only when the
experiment needs that dimension.

## Result Page Shape

Use this order for completed result pages:

1. status or run scope
2. result matrix
3. source reports, when individual artifacts need traceability
4. interpretation and decision impact
5. graphs
6. boundaries and follow-ups

Keep planning templates only in pending experiments. Once a matrix is curated,
move reusable expectations to `docs/experiment-catalog.md` or the experiment
README instead of leaving template sections in `results.md`.

## Evidence Flow

Raw run artifacts are written under `docs/reports/` and are ignored by default.
Curated tables live in each experiment's `results.md`. Cross-experiment
architecture conclusions live in `docs/evidence.md`, and operator-facing
choices live in `docs/recommendations.md`.

Reports that back a curated conclusion are promoted into the experiment's
committed `evidence/` directory so the claim stays auditable without a live
cluster:

```bash
./scripts/experiment promote-evidence --experiment kv-cache --report docs/reports/<report>.json
./scripts/experiment replay --experiment kv-cache
```

`promote-evidence` strips operational endpoints (such as load-balancer
hostnames) before copying, and `replay` renders the committed evidence with the
same table as `summarize-reports` using only `jq`.
