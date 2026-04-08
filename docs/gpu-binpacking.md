# GPU Bin Packing

## Objective

GPU bin packing is about placing workloads so expensive accelerator capacity is used efficiently instead of being stranded on oversized nodes.

## Problem example

Bad outcome:

- One pod that needs a single GPU lands on a node with four GPUs.
- The remaining capacity stays unusable because requests, memory, or scheduling rules prevent additional pods from sharing the node.

Better outcome:

- Node size and pod shape are aligned so several inference workers can share a larger node when that reduces waste.

## What this project should eventually demonstrate

- Intentional pod resource requests
- NodePool constraints that allow several useful GPU shapes
- Scheduling rules that avoid leaving large nodes mostly empty
- Observability that shows per-node GPU utilization instead of only pod counts

## Documentation checkpoint

Milestone 11 is complete only when the repository can explain not just that nodes launch, but that the launched nodes are a sensible fit for the workload mix.
