# Autoscaling And Queueing Behavior Results

## Live Cluster Run - 2026-05-07

All cases used the `default` serving profile. Burst cases were run before
autoscaling timeline capture was added; spike cases were rerun from zero GPU
nodes and include provisioning timings.

| Case | Client policy | Result status |
| --- | --- | --- |
| `burst-direct` | `direct` | complete |
| `burst-queued` | `bounded-queue` | complete |
| `spike-direct` | `direct` | complete |
| `spike-queued` | `bounded-queue` | complete |

## Result Summary

| Case | Successful | Dropped | Delivery ratio | p95 latency | Requests/sec | Peak active | Avg GPU | Max GPU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `burst-direct` | 2632 | 787 | 0.769816 | 14.62343968435 | 15.951366722404325 | 255 | 77.33333333333333 | 80 |
| `burst-queued` | 1656 | 0 | 1.000000 | 2.18936054675 | 10.02581860516098 | 24 | 84.66666666666667 | 86 |
| `spike-direct` | 1762 | 237 | 0.881441 | 14.230685990849999 | 15.892836835666975 | 254 | 78.5 | 80 |
| `spike-queued` | 1063 | 0 | 1.000000 | 1.9783313965 | 9.605043897862279 | 20 | 82 | 84 |

## Cold-Start Timeline

| Case | First NodeClaim | First GPU node | Pod scheduled | Container started | Model ready |
| --- | ---: | ---: | ---: | ---: | ---: |
| `spike-direct` | 3s | 35s | 65s | 354s | 425s |
| `spike-queued` | 12s | 35s | 65s | 357s | 439s |

## Reports

- `burst-direct`: `docs/reports/experiment-autoscaling-burst-direct-default-20260506-221447.json`
- `burst-queued`: `docs/reports/experiment-autoscaling-burst-queued-default-20260506-222712.json`
- `spike-direct`: `docs/reports/experiment-autoscaling-spike-direct-default-20260507-002654.json`
- `spike-queued`: `docs/reports/experiment-autoscaling-spike-queued-default-20260507-004305.json`

## Interpretation

The scale-from-zero path is dominated by container/image/model readiness, not
NodeClaim or node launch. Karpenter produced a serving NodeClaim in about 3-12s
and a GPU node in about 35s, while the vLLM container did not start until
354-357s and the model was not ready until 425-439s.

Direct open-loop clients maximized accepted throughput but shed work once client
capacity was exhausted. Bounded queued clients protected delivery ratio and tail
latency by limiting active concurrency, at the cost of lower completed volume and
request throughput during the same window.

The cluster also attempted spot capacity first, but spot replacement/launch was
blocked by EC2 Spot service-linked-role permissions. On-demand capacity provided
the successful GPU nodes for these runs.

## Graphs

- [Active-pressure sweep](graphs/active-pressure-sweep.svg) visualizes the
  latest zero-idle target sweep. It is included here as an autoscaling decision
  aid even though the source artifacts are evaluation reports rather than
  `autoscaling` experiment reports.

## Boundaries

- Burst cases predate autoscaling timeline capture, so use spike cases for
  cold-start stage timing.
- The active-pressure graph uses evaluation reports, not `autoscaling`
  experiment reports; keep detailed target-sweep interpretation in
  `docs/evidence.md`.
- The spot-capacity note reflects the permissions and capacity path observed in
  this run, not a general spot-market conclusion.

## Follow-Ups

- Repeat the direct/queued comparison after adding dedicated server-side queue
  histograms to separate model readiness from serving saturation.
- Re-run a spot-focused path once account permissions and interruption handling
  are production-shaped rather than synthetic.
