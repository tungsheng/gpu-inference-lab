# Request Pattern Utilization Results

No curated production run has been recorded yet.

## Planned Comparison

Run each traffic pattern with the same serving profile:

| Case | Serving profile | Result status |
| --- | --- | --- |
| `steady-small` | `default` | pending |
| `burst-small` | `default` | pending |
| `uneven-size-mix` | `default` | pending |
| `spike-to-zero` | `default` | pending |

## Result Template

For each case, record:

- completed requests and failed requests
- requests/sec and generation tokens/sec
- p50, p95, and p99 request latency
- peak waiting, running, and active requests
- average and max GPU utilization
- GPU memory used and free
- for `uneven-size-mix`, latency split by `request_shape`

## Interpretation Template

Tie utilization dips and tail-latency spikes back to the request pattern:

- steady traffic: baseline GPU occupancy and latency
- burst traffic: queue buildup and scheduler saturation
- uneven-size traffic: head-of-line effects from mixed request shapes
- spike-to-zero traffic: warmup, cooldown, and idle-capacity gaps
