# Operations

## Default Workflow

The repository now supports a four-command operational lifecycle:

- `./scripts/up`
- `./scripts/verify`
- `./scripts/evaluate --profile zero-idle`
- `./scripts/down`

`./scripts/up` prepares the platform:

- applies Terraform
- updates kubeconfig
- installs the AWS Load Balancer Controller
- installs Prometheus, Grafana, Prometheus Adapter, dashboards, and GPU metrics exporters
- installs Karpenter
- applies the GPU `EC2NodeClass` and `NodePool`
- applies the NVIDIA device plugin
- applies the dedicated inference service and public ingress

`./scripts/verify` proves the cold-start path:

- starts from zero GPU nodes
- applies the real vLLM deployment
- waits for Karpenter to provision one GPU node
- waits for the deployment to become Ready
- waits for the first successful external completion through the ALB edge
- deletes the deployment
- confirms the cluster returns to zero GPU nodes

`./scripts/evaluate` proves load-aware behavior:

- applies the real vLLM deployment and HPA
- drives a burst through `platform/tests/gpu-load-test.yaml`
- waits for HPA scale-out to two desired replicas
- waits for a second `NodeClaim`, second GPU node, and second Ready replica
- collects Prometheus- and DCGM-backed latency, queue, throughput, and GPU-utilization metrics
- writes Markdown and JSON reports under `docs/reports/`

`./scripts/down` reverses the stack:

- removes load-test and inference workload resources
- removes the warm and serving GPU capacity definitions
- removes the observability stack
- uninstalls Karpenter
- removes the NVIDIA device plugin
- destroys Terraform-managed infrastructure

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

The default operator story now includes:

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
