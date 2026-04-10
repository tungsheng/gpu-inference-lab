# platform/tests

This directory contains manual validation manifests for the platform.

Current checked-in examples:

- `gpu-test.yaml` to verify GPU scheduling and `nvidia-smi`
- `gpu-load-test.yaml` to drive sustained vLLM load high enough for HPA scale-out
- `cpu-scale-test.yaml` for the older CPU-only Karpenter pending-pod test path

These manifests are not part of the default scripted lifecycle.

Use `./scripts/up` and `./scripts/verify` for the baseline workflow. Use the
manifests in this directory only when you want additional manual checks or
optional scale-out experiments.
