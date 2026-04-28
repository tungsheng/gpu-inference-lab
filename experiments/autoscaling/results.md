# Autoscaling And Queueing Behavior Results

No production results have been recorded yet.

## Planned Comparison

Run each case with the same serving profile:

| Case | Client policy | Result status |
| --- | --- | --- |
| `burst-direct` | `direct` | pending |
| `burst-queued` | `bounded-queue` | pending |
| `spike-direct` | `direct` | pending |
| `spike-queued` | `bounded-queue` | pending |

## Result Template

For each case, record:

- first NodeClaim creation
- first GPU node Ready
- pod scheduled
- container started
- model Ready
- first successful completion
- completed requests, failed requests, and dropped client iterations
- buffering required in requests
- failure attribution
- p95 and p99 request latency
- peak waiting, running, and active requests

## Interpretation Template

Tie each burst failure to the most likely limiting stage:

- provisioning delay: NodeClaim or GPU node readiness is late
- pod startup delay: pod scheduling or container startup is late
- model readiness: model Ready occurs after the burst begins
- queue limit: dropped client iterations exceed the configured buffer capacity
- serving saturation: tail latency rises after capacity is Ready
