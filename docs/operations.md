# Operations

Use [dev-environment.md](dev-environment.md) for the step-by-step runbook. This
doc is the short operational summary.

## Lifecycle

- `./scripts/up` creates the dev environment, installs controllers and
  observability, applies the public service and ingress, and leaves GPU node
  count at `0`
- `./scripts/verify` applies only the vLLM deployment to prove the public
  first-response path from a zero-GPU baseline
- `./scripts/evaluate --profile zero-idle|warm-1` applies the deployment and
  HPA, runs the burst load, gathers metrics, writes reports, and returns the
  cluster to zero GPU nodes
- `./scripts/down` removes runtime resources, observability, capacity
  definitions, controllers, and Terraform-managed infrastructure

## Questions The Workflow Can Answer

- Does the public edge come up cleanly after cluster bootstrap?
- Can a pending GPU workload trigger Karpenter provisioning?
- How long does the first GPU node take to appear?
- How long does the pod take to go from scheduled to Ready?
- Can `vllm_requests_waiting` drive HPA replica scale-out?
- Does replica scale-out cause a second GPU node to join?
- What does p95 latency look like during a controlled burst?
- Is the GPU underutilized or saturated during the run?
- How much latency do you save by keeping one warm GPU node?

## Reports And Dashboards

The operator story includes:

- Prometheus metrics for vLLM queue depth, request latency, and token throughput
- Grafana dashboards for serving, capacity, and experiment summaries
- DCGM exporter metrics for GPU utilization
- `docs/reports/*.md` and `docs/reports/*.json` outputs from `./scripts/evaluate`

## Dev vs Production Boundary

The current dev environment still uses a public EKS endpoint for convenience.
That should not be treated as the production answer.

Production guidance:

- private cluster endpoint access
- SSM, bastion, or VPN-based admin access
- narrower public-access CIDR ranges
