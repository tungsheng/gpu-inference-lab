# Script Templates

These templates are rendered by `./scripts/experiment` into Kubernetes
ConfigMaps for experiment client workloads.

- `experiment-load-test.js.tpl`: k6 completion load client
- `experiment-stream-client.py.tpl`: Python streaming completion client

Keep runtime client logic here instead of embedding long script bodies in the
shell renderer. The renderer owns substitution and manifest wiring; the
templates own client behavior.
