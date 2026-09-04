# Test Helpers

- `test-helpers.sh`: assertions, temp-directory lifecycle, stub writing, and the
  deterministic edge configuration every test inherits
- `cluster-stub.sh`: composable stubs for the CLI tools the lifecycle scripts
  drive

## Writing a stub

Compose the named bundles and add only the arms whose response your test
depends on. Arms added before a bundle shadow it, which is how a test makes one
command fail while the rest of the workflow stays on the happy path:

```bash
kubectl_stub_reset
kubectl_arm "'get crd nodepools.karpenter.sh'" "exit 1"
kubectl_bundle_down_happy_path
kubectl_stub_write
```

The catch-all stays strict on purpose: an unexpected command fails the stub, so
a script that starts issuing a new one is noticed rather than tolerated.

Reach for a literal `write_stub` when a test drives a genuinely different
scenario. The failure-path tests do this deliberately — their stubs are not
duplicates of each other, they are nine different workflows.
