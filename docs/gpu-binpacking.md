# GPU Bin Packing

## Why This Matters

Once capacity-aware autoscaling is in place, the next question is no longer
"can I launch another GPU node?" It becomes "am I using the GPU nodes I launch
efficiently?"

That is the bin-packing problem for this repo.

## The Failure Mode

Bad outcome:

- one inference pod lands on a node shape that has much more GPU capacity than
  the workload can use
- the remaining GPU, memory, or CPU headroom is stranded
- cost rises without a proportional latency or throughput gain

Better outcome:

- pod shape and node shape are intentionally matched
- one GPU can serve multiple useful active requests
- scaling decisions reflect capacity per GPU, not just pod count

## What This Repo Should Eventually Prove

The project will be ready to claim a stronger efficiency story when it can show:

- one GPU can sustain a measurable number of active requests
- per-node GPU utilization explains whether a node was saturated or underused
- multiple node shapes or placement patterns reveal useful packing tradeoffs
- cost per burst improves when the platform uses capacity more efficiently

## Good Follow-On Experiments

After Milestone 9, likely experiments include:

- comparing one-pod-per-GPU against multi-request-per-GPU tuning
- introducing larger node shapes where packing tradeoffs are visible
- reporting useful work per GPU alongside latency and cost
- using dashboards and reports to explain stranded capacity, not just launched
  capacity

## Success Criteria

This milestone is complete only when the repo can explain not just that GPU
nodes launched, but that the chosen node shapes and serving settings were a
sensible fit for the observed workload.
