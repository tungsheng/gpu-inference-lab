# Failure And Mitigation Drill Results

## Status

Partial live capacity-recovery pass on 2026-06-07. The catalog and
`./scripts/failure` command are usable, but the capacity-recovery suite is not
yet a promotion gate because the account cannot currently launch the required
Spot GPU baseline.

## Latest Live Run

| Scenario | Mitigation | Result | Notes |
| --- | --- | --- | --- |
| `spot-unavailable` | `ondemand-fallback` | Passed | Spot NodePool was withdrawn and the service scaled to on-demand. First public response was 427s, second ready replica was 904s, p95 request latency was 117s, peak active requests was 256, and average GPU utilization was 18.1%. |
| `spot-interruption` | `ondemand-fallback` | Blocked before recovery | Karpenter attempted `gpu-serving-spot`, but EC2 returned `MaxSpotInstanceCountExceeded` plus `UnfulfillableCapacity`, then fallback created an on-demand first node. The patched evaluator stopped at first-node capacity discovery instead of waiting for vLLM cold start. |

Follow-up from this run: `scripts/up` now ensures the EC2 Spot service-linked
role before installing Karpenter, and `scripts/evaluate` now stops
`spot-interruption` as soon as the first GPU node is not spot-backed. The
precondition failure prints recent Karpenter Spot diagnostics, writes partial
reports, and avoids the several-minute vLLM image/model startup wait.

Remaining live blocker: raise or free EC2 Spot quota for the target GPU families
in `us-west-2`, or broaden the Spot NodePool to additional viable GPU
instance-size/family combinations before treating `spot-interruption` as a
promotion gate.

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
