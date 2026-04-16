# platform/tests

This directory contains validation manifests for the platform.

Active validation manifests:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `gpu-load-test.yaml` to drive `vllm_requests_running` high enough for HPA scale-out
- `gpu-warm-placeholder.yaml` to keep one on-demand serving GPU node alive for
  the `warm-1` evaluation profile without consuming the GPU

`gpu-load-test.yaml` is now part of the scripted evaluation path:

- `./scripts/evaluate --profile zero-idle`
- `./scripts/evaluate --profile warm-1`

Use `./scripts/verify` for the fast cold-start smoke test and the manifests in
this directory when you want additional manual checks.
