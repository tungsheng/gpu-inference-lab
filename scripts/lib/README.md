# Script Library

`scripts/_common.sh` is a compatibility loader for the public command scripts.
Shared platform helpers live here so the executable entry points in `scripts/`
can stay focused on user-facing workflows.

Keep command-specific orchestration in the executable scripts. Move reusable
cluster constants, wait helpers, reporting helpers, and install/uninstall
building blocks into this library when they are needed by more than one
workflow.

Current library files:

- `platform.sh`: shared cluster, manifest, and wait helpers for the public
  scripts
- `destroy-recovery.sh`: optional teardown diagnostics plus orphan CNI ENI and
  EKS node security-group cleanup helpers for `./scripts/down`
- `evaluate-reports.sh`: schema metadata for `./scripts/evaluate` report
  artifacts
