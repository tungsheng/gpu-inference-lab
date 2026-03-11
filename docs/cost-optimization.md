# Cost Optimization

## Why this matters

GPU capacity is usually the most expensive part of an inference platform. Cost work in this project is not optional cleanup. It is a core part of the design.

## Milestone 7 target

Milestone 7 adds a mixed provisioning strategy:

- `gpu-spot` for cheaper interruptible capacity
- `gpu-ondemand` for fallback and baseline reliability

This split should make the platform able to keep serving when spot capacity is reclaimed or temporarily unavailable.

## Decisions to document when Milestone 7 is implemented

- Which workloads are allowed to use spot nodes
- Which workloads require on-demand nodes
- How interruption handling affects model warm-up and request retries
- Whether fallback behavior is automatic or capacity is partitioned intentionally

## Relationship to warm pools

Warm pools reduce latency but increase idle cost. Spot capacity reduces cost but increases interruption risk. The platform should eventually balance both instead of optimizing only one dimension.
