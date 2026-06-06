# Failure And Mitigation Drill Results

## Status

Partial live run on 2026-06-06. The catalog and `./scripts/failure` command are
usable, but the capacity-recovery suite is not yet a promotion gate.

## Latest Live Run

| Scenario | Mitigation | Result | Notes |
| --- | --- | --- | --- |
| `spot-unavailable` | `ondemand-fallback` | Passed | Spot NodePool was withdrawn and the service scaled to on-demand. First public response was 459s, second ready replica was 925s, and final cleanup to zero GPU nodes was 2183s. |
| `spot-interruption` | `ondemand-fallback` | Failed before recovery | The first serving node landed on on-demand, then the drill withdrew on-demand and left the service without ready endpoints. The load job failed with 3599 failed requests before HPA could scale out. |

Follow-up from this run: `scripts/evaluate` now fails fast when a load job
reaches `Failed` before HPA scale-out, writes partial reports for interruption
precondition failures, refuses to withdraw on-demand unless the first serving
node is already spot-backed, and steers interruption recovery with temporary
NodePool weights instead of deleting a live spot NodePool.

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
