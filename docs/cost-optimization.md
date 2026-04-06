# Cost Optimization

## Why this matters

GPU capacity is the most expensive part of this platform. The point of the
dynamic serving path is not just nicer autoscaling behavior. It is removing the
default cost of an always-on GPU node when nobody is using the model.

## Baseline comparison

Using the official AWS us-west-2 EC2 on-demand price sheet fetched on
`2026-03-23`:

- `g4dn.xlarge`: `$0.526/hour`
- `g5.xlarge`: `$1.006/hour`
- `m7i-flex.large`: `$0.09576/hour`

The previous baseline kept one managed `g4dn.xlarge` GPU node available all the
time. The current baseline keeps that node count at zero until the inference
deployment requests a GPU.

That means:

- fixed baseline cost = `24 * GPU hourly price`
- dynamic baseline cost = `active GPU hours * GPU hourly price`

The system-node baseline still exists in both cases, so the meaningful delta is
the GPU line item.

## Fixed vs dynamic note

Use the measurement report from `./scripts/dev measure` to plug
in the actual active GPU time for your run.

Worked example if Karpenter lands on `g4dn.xlarge` and the service is active
for one hour in a day:

- fixed GPU baseline: `24 * $0.526 = $12.62/day`
- dynamic GPU baseline: `1 * $0.526 = $0.53/day`
- savings: about `$12.10/day`, or roughly `96%` of the fixed GPU idle spend

If Karpenter has to use `g5.xlarge` instead, the per-active-hour GPU price is
higher, but the same dynamic-vs-fixed principle still holds: the platform pays
for **used GPU hours**, not for a permanently idling node.

In practice, the dynamic path trades lower idle cost for a longer first-request
latency because the first GPU node has to be launched and initialized.

## Next cost milestone

Milestone 8 should add a mixed provisioning strategy:

- `gpu-spot` for cheaper interruptible capacity
- `gpu-ondemand` for fallback and baseline reliability

That will let the platform optimize both **idle cost** and **active-hour cost**.
