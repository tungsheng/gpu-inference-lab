# platform/tests

This directory contains validation manifests for the platform.

Active validation manifests:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `gpu-load-test.yaml` to drive `vllm_requests_waiting` high enough for HPA scale-out

`gpu-load-test.yaml` is now part of the scripted evaluation path:

- `./scripts/evaluate --profile zero-idle`
- `./scripts/evaluate --profile warm-1`

Use `./scripts/verify` for the fast cold-start smoke test and the manifests in
this directory when you want additional manual checks.
