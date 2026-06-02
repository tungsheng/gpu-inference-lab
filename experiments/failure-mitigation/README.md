# Failure And Mitigation Drills

## Goal

Make failure testing feel like an experiment matrix instead of a set of manual
chaos commands.

Each drill combines:

- a named failure scenario
- a workload case
- a mitigation profile
- a recovery gate
- a reportable outcome

Use `./scripts/failure` as the operator entry point.

## Commands

Inspect the catalog:

```bash
./scripts/failure list
./scripts/failure show scenario spot-interruption
./scripts/failure show mitigation bounded-admission
./scripts/failure show suite capacity-recovery
```

Render the exact plan without mutating the cluster:

```bash
./scripts/failure run \
  --scenario spot-interruption \
  --mitigation ondemand-fallback \
  --dry-run
```

Run a small suite plan:

```bash
./scripts/failure matrix --suite capacity-recovery --dry-run
```

## Initial Scope

The first slice covers five high-signal drills:

| Scenario | Layer | Primary mitigation question |
| --- | --- | --- |
| `spot-unavailable` | capacity | can the system fall back to on-demand when preferred spot is unavailable? |
| `spot-interruption` | capacity | can the system replace interrupted spot capacity and return to two Ready replicas? |
| `gpu-node-loss` | node | can serving recover after a Karpenter-backed GPU node is withdrawn? |
| `vllm-pod-delete` | pod | can the deployment replace a failed serving process and resume public traffic? |
| `overload-direct-vs-bounded` | admission | does bounded admission convert excess load into explicit backpressure? |

## Readout

Compare trigger time, replacement time, recovered Ready time, public response
recovery, failed/dropped/interrupted work, delivery ratio, p95/p99 latency,
capacity type, and cleanup status.

Generated reports belong under `docs/reports/`. Curated conclusions should
replace the planning table in `results.md` only after live runs are complete.
