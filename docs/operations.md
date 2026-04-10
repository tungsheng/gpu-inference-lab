# Operations

## Default Workflow

The repository now supports a minimal operational lifecycle:

- `./scripts/up`
- `./scripts/verify`
- `./scripts/down`

The `up` flow:

- applies Terraform
- updates kubeconfig
- installs the AWS Load Balancer Controller
- installs Karpenter
- applies the GPU `EC2NodeClass` and `NodePool`
- applies the NVIDIA device plugin
- applies the dedicated inference service and public ingress

The `verify` flow:

- starts from zero GPU nodes
- applies the real vLLM deployment
- waits for Karpenter to provision one GPU node
- waits for the deployment to become Ready
- waits for the first successful external completion through the ALB edge
- deletes the deployment
- confirms the cluster returns to zero GPU nodes

The `down` flow:

- removes the ingress first so the ALB can be deleted cleanly
- removes the inference service and deployment
- removes Karpenter resources
- uninstalls Karpenter
- removes the NVIDIA device plugin
- destroys Terraform-managed infrastructure

## Questions The Default Workflow Can Answer

- Does the public edge come up cleanly after cluster bootstrap?
- Can a pending GPU workload trigger Karpenter provisioning?
- Does the first vLLM replica become Ready?
- Does the public `/v1/completions` path return a successful response?
- Does deleting the workload return the cluster to zero GPU nodes?

## Deferred To Manual Or Future Work

- queue-depth-driven HPA validation
- Prometheus- and Grafana-backed production metrics
- load-test-driven scale-out experiments
- warm-node cost and latency comparisons
