# platform/tests

This directory contains manual validation manifests for the platform.

Current checked-in examples:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `cpu-scale-test.yaml` for the optional Karpenter pending-pod test path

These manifests are not applied automatically by `./scripts/apply-dev.sh`.
