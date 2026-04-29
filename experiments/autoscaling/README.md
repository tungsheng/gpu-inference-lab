# Autoscaling And Queueing Behavior

## Goal

Show that HPA and Karpenter scale-out is useful but not instant, then estimate
how much traffic must be buffered while capacity, pods, containers, and the
model become ready.

## Cases

| Case | Client policy | Load model | Purpose |
| --- | --- | --- | --- |
| `burst-direct` | `direct` | open-loop arrival rate | expose request drops during overloaded bursts |
| `burst-queued` | `bounded-queue` | closed-loop VUs | approximate queued/backpressured admission |
| `spike-direct` | `direct` | open-loop arrival rate | measure spike-to-zero cold path without buffering |
| `spike-queued` | `bounded-queue` | closed-loop VUs | estimate queue protection during spike-to-zero |

The queued cases are a controlled closed-loop approximation. They do not replace
a production queue.

## Commands

Render a queued load job:

```bash
./scripts/experiment render-load \
  --experiment autoscaling \
  --case burst-queued \
  --output /tmp/autoscaling-burst-queued.yaml
```

Measured live-cluster run after `./scripts/up`:

```bash
./scripts/experiment run \
  --experiment autoscaling \
  --case burst-direct \
  --profile default
```

Run direct and queued versions with the same serving profile before comparing
results.

## Readout

Compare first NodeClaim, node Ready, pod scheduled, container started, model
Ready, first completion, failed requests, dropped iterations, required buffer,
p95/p99 latency, and peak waiting/running/active requests.
