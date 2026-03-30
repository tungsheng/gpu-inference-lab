# platform/tests

This directory contains manual validation manifests for the platform.

Current checked-in examples:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `gpu-load-test.yaml` to drive sustained vLLM load high enough for HPA scale-out
- `cpu-scale-test.yaml` for the older CPU-only Karpenter pending-pod test path

These manifests are not applied automatically by `./scripts/apply-dev.sh`.
Use `./scripts/measure-gpu-serving-path.sh` when you want the repo to apply the
GPU serving manifest, run the load test, and write a timeline report in one
pass.
