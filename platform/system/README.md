# platform/system

This directory contains cluster-level manifests used by the minimal lifecycle
scripts.

Current checked-in examples:

- `nvidia-device-plugin.yaml` for GPU runtime discovery on tainted GPU nodes

Related system components:

- The AWS Load Balancer Controller is installed with Helm by `./scripts/up`
- Its service account manifest remains under
  `platform/controller/aws-load-balancer-controller/`
