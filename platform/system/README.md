# platform/system

This directory contains cluster-level manifests used by the dev-environment
helpers.

Current checked-in examples:

- `nvidia-device-plugin.yaml` for GPU runtime discovery on tainted GPU nodes

Related system components:

- The AWS Load Balancer Controller is installed with Helm by
  `scripts/post-terraform-apply.sh`
- Its service account manifest remains under
  `platform/controller/aws-load-balancer-controller/`
