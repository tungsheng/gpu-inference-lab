# Cost Optimization

## Baseline Cost Posture

The repo still defaults to a **zero-idle GPU baseline**:

- system nodes stay up all the time
- GPU nodes appear only when a workload requests `nvidia.com/gpu`
- when the workload disappears, Karpenter can consolidate the empty GPU node
  back down

That gives you low idle GPU cost at the price of cold-start latency.

## The Tradeoff This Milestone Measures

The repository now automates the first real cost/latency comparison:

- `./scripts/evaluate --profile zero-idle`
- `./scripts/evaluate --profile warm-1`

The `zero-idle` profile measures:

- first GPU node latency from zero
- first public response latency from zero
- burst behavior when the HPA scales from one to two replicas
- return to zero GPU nodes after cleanup

The `warm-1` profile measures:

- the same burst path with one warm GPU node already present
- lower first-response latency because node launch is already paid
- the explicit idle-cost penalty of keeping one GPU node warm

## What The Reports Capture

Each evaluation report writes:

- first GPU node timing
- first Ready replica timing
- first public response timing
- HPA scale-out timing
- second GPU node timing
- second Ready replica timing
- p95 latency during burst
- GPU utilization during burst
- estimated idle cost per hour for the profile
- estimated burst cost for the measured run

## Instance-Family Flexibility

The serving `NodePool` currently allows:

- `g4dn.xlarge`
- `g5.xlarge`

That improves the chance that a pending inference pod can find compatible GPU
capacity in constrained regions or AZs.

## Reading The Warm-Node Tradeoff

The warm profile is better when:

- first-response latency matters more than pure idle efficiency
- bursts are frequent enough that you want one GPU already in the cluster

The zero-idle profile is better when:

- traffic is sparse
- cost discipline matters more than the first-request penalty
- you are comfortable paying the cold-start tax on the first burst
