# Operations

## Current operational workflow

The repository now supports a full dynamic-GPU lifecycle:

- `terraform -chdir=infra/env/dev init`
- `./scripts/dev up`
- `./scripts/dev measure`
- `./scripts/dev down`

The apply flow:

- applies Terraform
- updates kubeconfig
- installs the AWS Load Balancer Controller
- installs metrics-server
- installs Karpenter
- applies the GPU `EC2NodeClass` and `NodePool`
- applies the NVIDIA device plugin
- applies the dedicated inference service and public ingress
- applies the sample ingress workload

The measurement flow:

- starts from zero GPU nodes
- waits for the public inference edge hostname
- applies the real vLLM inference deployment
- waits for Karpenter to provision GPU capacity
- waits for the first successful external completion through the ALB edge
- runs the checked-in load test
- captures scale-out and scale-down timestamps
- writes a Markdown and optional JSON report

The destroy flow:

- removes the ingress first so the ALB can be deleted cleanly
- removes the inference service and sample workload
- removes GPU smoke-test, load-test, and inference workloads
- removes Karpenter resources and waits for managed GPU nodes to terminate
- removes the NVIDIA device plugin
- removes metrics-server
- removes the app namespace
- uninstalls the AWS Load Balancer Controller
- destroys Terraform-managed infrastructure

## Questions the platform can answer now

- How long the first GPU node takes to appear after a pending inference pod
- How long it takes before `nvidia.com/gpu` is allocatable on that node
- How long the first inference replica takes to become Ready
- How long the first successful external completion takes through the public ALB edge
- Whether sustained traffic causes HPA-driven scale-out
- Whether the extra GPU node is consolidated away after load stops
- Whether the cluster can return all the way to zero GPU nodes

## Still missing for later milestones

- Prometheus and Grafana for persistent metrics
- GPU utilization dashboards instead of API-polling scripts
- edge rate limiting and tighter readiness policies
- spot/on-demand split policies
- warm-pool controls for lower first-request latency
