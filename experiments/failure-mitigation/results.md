# Failure And Mitigation Drill Results

## Status

Planned. The catalog and `./scripts/failure` command define the initial drill
surface; live results should replace this section after measured runs.

## Planned Matrix

| Scenario | Mitigation | Workload | Recovery gate |
| --- | --- | --- | --- |
| `spot-unavailable` | `ondemand-fallback` | `burst-queued` | on-demand second GPU node |
| `spot-interruption` | `ondemand-fallback` | `burst-queued` | replacement GPU node and two Ready replicas |
| `vllm-pod-delete` | `warm-1-active-pressure` | `steady-recovery` | serving deployment Ready and public 200 |
| `gpu-node-loss` | `warm-1-active-pressure` | `steady-recovery` | serving deployment Ready and public 200 |
| `overload-direct-vs-bounded` | `baseline` | `burst-direct` | delivery and latency recorded |
| `overload-direct-vs-bounded` | `bounded-admission` | `burst-queued` | delivery and latency recorded |

## Promotion Gate

A curated conclusion needs trigger timing, recovery timing, failed/dropped or
interrupted work, p95/p99 latency, capacity type, and cleanup status. Partial
reports can support operational notes but should not become architecture
recommendations.
