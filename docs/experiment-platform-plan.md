# Experiment Catalog Contract

This document describes the current experiment catalog contract. Use
[experiments-summary.md](experiments-summary.md) for experiment status and
[roadmap.md](roadmap.md) for planned work.

## Layout

Each experiment lives under `experiments/<name>/` and uses the same basic shape:

- `experiment.yaml`: title, description, metrics, and report intent
- `cases.csv`: workload cases
- `serving-profiles.csv`: optional vLLM profile overrides
- `results.md`: curated conclusions or a result template

Shared defaults live in `experiments/_profiles/serving-defaults.csv`.
Experiment-specific profiles should only override fields that matter to the
question being asked.

## Local Commands

These commands do not require a live cluster because they only inspect the
catalog or render local artifacts. They do not apply Kubernetes resources, run
traffic, collect metrics, or produce measured results.

```bash
./scripts/experiment list
./scripts/experiment validate
./scripts/experiment show kv-cache
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-load.yaml
./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile long-context \
  --output /tmp/vllm-long-context.yaml
./scripts/experiment render-report \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched
```

## Live Commands

Measured runs require a configured Kubernetes context from `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default

./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --profile default \
  --samples 5
```

The runner applies rendered serving and load manifests to the cluster, waits for
the job, parses client summaries, writes Markdown and JSON reports under
`docs/reports/`, stores the client log next to the JSON report, and cleans up
rendered resources unless `--preserve-serving` or `--preserve-load` is used.

## Report Rules

- generated report artifacts belong under `docs/reports/`
- generated reports are ignored by default
- force-add a generated report only when it is intentionally part of the project
  narrative
- curated conclusions belong in `experiments/<name>/results.md`
- cross-experiment narrative belongs in `docs/experiments-summary.md`

## Validation Rules

`./scripts/experiment validate` should pass after any catalog edit. It checks:

- experiment names and case IDs
- CSV shape and required fields
- shared serving defaults
- experiment-specific serving overrides
- request-shape, client-policy, and cost-profile references
- renderer templates

Keep the catalog boring on purpose: one controlled question, explicit workload
inputs, explicit serving profile choices, and reports that separate
configuration from measured results.
