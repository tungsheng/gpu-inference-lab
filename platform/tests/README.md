# platform/tests

This directory contains the manual and scripted validation manifests for the
platform.

## Files

- `gpu-test.yaml`: manual GPU smoke test that validates scheduling and
  `nvidia-smi`
- `gpu-load-test.yaml`: k6 burst job used by `./scripts/evaluate`
- `gpu-warm-placeholder.yaml`: tiny deployment that keeps one on-demand serving
  node alive for the `warm-1` profile without requesting a GPU

## How They Are Used

`./scripts/verify` is the fast default cold-start proof and does not use the
manifests in this directory.

`./scripts/evaluate` does use them:

- `gpu-load-test.yaml` is the burst generator that drives the autoscaling path
- `gpu-warm-placeholder.yaml` is applied only for the `warm-1` profile

## Why The Load Test Matters

The k6 job uses a ramping arrival-rate pattern so it keeps pressure on the
service even as latency rises. That makes HPA scale-out and second-node
provisioning much easier to measure consistently.
