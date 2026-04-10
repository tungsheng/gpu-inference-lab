# Cost Optimization

## Baseline Cost Posture

The repo defaults to an **elastic GPU baseline** instead of a fixed GPU node
group.

That means:

- system nodes stay up all the time
- GPU nodes appear only when a workload requests `nvidia.com/gpu`
- when the workload disappears, Karpenter can consolidate the empty GPU node
  back down

The default tradeoff is simple:

- you save idle GPU spend
- you pay cold-start latency on the first request after scaling from zero

## What The Default Workflow Optimizes For

The current scripts optimize for:

- simple bring-up
- a clear first-response validation
- a clean return to zero GPU nodes

They do **not** currently automate warm-node or benchmark-style cost
comparisons. Those experiments are now manual or future work rather than part
of the day-one lifecycle.

## Instance-Family Flexibility

The serving `NodePool` currently allows:

- `g4dn.xlarge`
- `g5.xlarge`

That improves the chance that a pending inference pod can find compatible GPU
capacity in constrained regions or AZs.

## Manual Next Steps

If you want to keep exploring cost tradeoffs, compare:

- time to first GPU node
- time to first successful public response
- how quickly the cluster returns to zero GPU nodes
- whether a warm-node policy is worth the extra idle spend for your traffic pattern
