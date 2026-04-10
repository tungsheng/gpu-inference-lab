# platform/tests

This directory contains validation manifests for the platform.

Current checked-in examples:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `gpu-load-test.yaml` to drive `vllm_requests_waiting` high enough for HPA scale-out
- `cpu-scale-test.yaml` for the older CPU-only Karpenter pending-pod test path

`gpu-load-test.yaml` is now part of the scripted evaluation path:

- `./scripts/evaluate --profile zero-idle`
- `./scripts/evaluate --profile warm-1`

Use `./scripts/verify` for the fast cold-start smoke test and the manifests in
this directory when you want additional manual checks.
