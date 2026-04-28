# Autoscaling And Queueing Behavior

## Goal

Show that Karpenter/HPA scale-out is useful but not instant, and quantify how
much traffic needs to be buffered while GPU capacity, pods, containers, and the
model become ready.

## Cases

| Case | Client policy | Load model | Purpose |
| --- | --- | --- | --- |
| `burst-direct` | `direct` | open-loop arrival rate | expose request drops during overloaded bursts |
| `burst-queued` | `bounded-queue` | closed-loop VUs | approximate queued/backpressured admission |
| `spike-direct` | `direct` | open-loop arrival rate | measure spike-to-zero cold path without buffering |
| `spike-queued` | `bounded-queue` | closed-loop VUs | estimate queue protection during spike-to-zero |

The direct cases use k6 `ramping-arrival-rate`. The queued cases use
`ramping-vus`, which is a closed-loop approximation: each virtual user waits
for the previous request to complete before issuing the next request. This does
not replace a production queue, but it gives a controlled comparison point for
backpressure behavior.

## Render A Queued Load Job

```bash
./scripts/experiment render-load \
  --experiment autoscaling \
  --case burst-queued \
  --output /tmp/autoscaling-burst-queued.yaml
```

The rendered manifest tags requests with `client_policy` and `client_mode`.
Reports also preserve the configured buffer capacity and max queue wait so the
result can state whether a real queue would have needed more headroom.

## Run One Live Case

`run` requires a configured Kubernetes context and a live cluster from
`./scripts/up`.

```bash
./scripts/up

./scripts/experiment run \
  --experiment autoscaling \
  --case burst-direct \
  --profile default
```

Run `burst-direct` and `burst-queued` back to back with the same serving
profile. Then repeat with `spike-direct` and `spike-queued` when validating the
scale-from-zero path.

## Metrics To Capture

- first NodeClaim creation
- first GPU node Ready
- pod scheduled
- container started
- model Ready
- first successful completion
- failed requests and dropped client iterations
- buffering required in requests
- p95 and p99 request latency
- peak waiting, running, and active requests

## Expected Interpretation

The direct cases should show whether burst traffic fails before new capacity
can serve it. The queued cases should show how much client-side buffering would
have been required to absorb the same burst. If direct failures happen before
the first successful completion, attribute them to provisioning/model readiness;
if k6 drops iterations, attribute them to queue or client-admission limits; if
latency rises after the model is Ready, attribute the pressure to serving
saturation.
