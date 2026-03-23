# Operations

## Current operational workflow

The repository currently supports a full dev-environment lifecycle:

- `terraform -chdir=infra/env/dev init`
- `./scripts/apply-dev.sh`
- `./scripts/destroy-dev.sh`

The apply flow:

- Applies Terraform for the dev environment.
- Updates local kubeconfig.
- Applies the AWS Load Balancer Controller CRDs and installs the pinned Helm chart.
- Applies the checked-in NVIDIA device plugin daemonset for the tainted GPU
  node group and waits for GPU capacity to appear.
- Waits for the controller to become ready.
- Applies the sample application manifests.

That helper is intentionally scoped to the baseline ingress path. Karpenter
installation and test workloads are still managed as a separate workflow.

The destroy flow:

- Removes the ingress first so the ALB can be deleted cleanly.
- Removes the sample workload.
- Removes the GPU smoke-test and example inference workload if they were applied.
- Removes Karpenter test resources and waits for Karpenter-managed nodes to terminate if Karpenter has been installed.
- Removes the checked-in NVIDIA device plugin daemonset.
- Uninstalls the AWS Load Balancer Controller.
- Destroys the Terraform environment.

That ordered teardown is important because the ALB is created indirectly by Kubernetes rather than directly by Terraform.

## Future observability work

Milestone 13 should add:

- Prometheus
- Grafana
- GPU metrics
- Basic dashboards for node health, pod health, inference latency, and cluster capacity

## Future hardening work

Milestone 14 should add:

- Rate limiting at the edge or application layer
- Health checks tied to real workload readiness
- PodDisruptionBudget resources
- Security policies and tighter access control defaults

## Operating questions the platform should answer

- Which workloads are consuming GPU capacity
- How long new GPU nodes take to become schedulable
- Whether spot interruptions are affecting availability
- Whether inference traffic is causing queue buildup or latency spikes
- Whether warm pools are reducing latency enough to justify cost

## Related docs

- `docs/dev-environment.md`
- `docs/scaling.md`
- `docs/cost-optimization.md`
