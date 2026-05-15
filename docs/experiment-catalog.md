# Experiment Catalog

The catalog defines controlled questions for the decision engine. Each
experiment isolates one architecture decision and keeps workload, configuration,
measurement, and conclusion separate.

Validate catalog edits with:

```bash
./scripts/experiment validate
```

## Catalog

| Experiment | Status | Decision question | Location |
| --- | --- | --- | --- |
| KV cache vs concurrency | measured long-context knee; scheduler follow-ups ready | How does prompt context reduce stable concurrency and throughput? | `experiments/kv-cache/` |
| Autoscaling and queueing behavior | measured direct/queued burst and spike cases | How much traffic is lost or delayed while GPU capacity and model readiness catch up? | `experiments/autoscaling/` |
| Prefill vs decode timing | default and mixed-profile reports curated | How do prompt-heavy and decode-heavy requests shift TTFT and inter-token timing? | `experiments/prefill-decode/` |
| Batching scheduler tradeoffs | steady and burst matrices curated for `512/128` | How do scheduler limits trade throughput for tail latency? | `experiments/batching/` |
| Request pattern utilization | default-profile four-pattern matrix curated | How do steady, burst, uneven-size, and spike-to-zero patterns affect GPU occupancy? | `experiments/request-patterns/` |
| Cost per useful work | steady and burst cost matrices curated | How much cheaper does the same GPU become when batching increases useful work? | `experiments/cost/` |
| FP4 quantization optimization | renderable; Blackwell capacity attempt blocked | Does SmoothQuant improve NVFP4 recovery enough to justify its cost? | `experiments/fp4/` |

## File Contract

Each experiment lives under `experiments/<name>/`:

- `experiment.yaml`: title, question, workload, metrics, and artifact intent
- `cases.csv`: workload cases
- `serving-profiles.csv`: optional vLLM profile overrides
- `serving-extensions.csv`: advanced serving metadata such as tensor
  parallelism, quantization provenance, or KV-cache dtype
- `request-shapes.csv`: optional mixed request-shape definitions
- `client-policies.csv`: optional admission/client behavior definitions
- `cost-profiles.csv` and `cost-details.csv`: optional cost inputs
- `accuracy-cases.csv`: optional accuracy workloads
- `quantization/`: optional quantization jobs and recipes
- `results.md`: curated conclusions or a result template

Shared defaults live in `experiments/_profiles/serving-defaults.csv`.
Experiment-specific profiles override only the fields that matter to the
question.

## Result Standard

Each completed experiment records the fields relevant to its decision:

- serving profile and model settings
- workload cases that were run
- successful, failed, dropped, interrupted, offered, and unserved work
- delivery ratio
- p50, p95, and p99 latency
- TTFT or inter-token latency for streaming cases
- throughput in requests/sec and tokens/sec
- waiting, running, and active request pressure
- GPU utilization and memory pressure when available
- cost, accuracy, and quantization build fields for those experiments
- practical architecture conclusion

## Ownership

- Commands live in [Runbook](runbook.md).
- Generated report artifacts belong under `docs/reports/` and are ignored by
  default.
- Curated per-experiment conclusions belong in `experiments/<name>/results.md`.
- Cross-experiment architecture narrative belongs in [Evidence](evidence.md).
- Operator-facing supported, partial, rejected, and pending choices belong in
  [Recommendations](recommendations.md).
