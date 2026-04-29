# Dev Environment Workflow

The repo has one active environment: `infra/env/dev`. The workflow is:

1. bring up the cluster and platform services
2. prove cold start with `./scripts/verify`
3. measure burst behavior with `./scripts/evaluate`
4. tear everything down

Use [operations.md](operations.md) when you only need to choose a command.

## Prerequisites

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- access to `us-west-2`

Run local tests at any point:

```bash
./test/run.sh
```

## Happy Path

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8
./scripts/down
```

Optional resilience runs:

```bash
./scripts/evaluate --profile zero-idle --resilience spot-unavailable
./scripts/evaluate --profile zero-idle --resilience spot-interruption
```

## Bring The Environment Up

```bash
./scripts/up
```

Common Terraform pass-through variants:

```bash
./scripts/up -auto-approve
./scripts/up -var-file=dev.tfvars
```

`./scripts/up` performs the platform bootstrap:

1. runs `terraform init` and `terraform apply` in `infra/env/dev`
2. updates local kubeconfig from Terraform outputs
3. installs the AWS Load Balancer Controller
4. installs Prometheus, Grafana, Prometheus Adapter, Pushgateway, dashboards,
   and GPU exporters
5. installs Karpenter CRDs and controller
6. applies the shared GPU `EC2NodeClass` and both serving `NodePool`s
7. applies the NVIDIA device plugin
8. applies the public inference service and ingress
9. waits for the ingress hostname and prints the public URL

Expected state:

- system nodes are present and labeled `workload=system`
- Prometheus, Grafana, and the custom metrics API are Ready
- Karpenter is Ready
- the public inference ingress has a hostname
- GPU node count is still `0`

## Prove Cold Start

```bash
./scripts/verify
```

`./scripts/verify` applies only `platform/inference/vllm-openai.yaml`, waits for
one GPU node, waits for one Ready vLLM replica, retries the public
`/v1/completions` path until it gets `200`, deletes the deployment, and waits
for GPU capacity to return to zero.

Use this when you want to validate GPU provisioning, model startup, public
ingress routing, and cleanup without running a full burst experiment.

## Run Burst Evaluations

Default running-request baseline:

```bash
./scripts/evaluate --profile zero-idle
```

Active-pressure policy:

```bash
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
```

Warm-node comparison:

```bash
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
```

Active-target sweep:

```bash
./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8
```

Resilience drills:

```bash
./scripts/evaluate --profile zero-idle --resilience spot-unavailable
./scripts/evaluate --profile zero-idle --resilience spot-interruption
```

Profile behavior:

| Profile | Baseline | Tradeoff |
| --- | --- | --- |
| `zero-idle` | zero GPU nodes before the run | lowest idle GPU cost, highest cold-start penalty |
| `warm-1` | one on-demand serving node held by `gpu-warm-placeholder` | faster first response, higher idle cost |

Policy behavior:

| Policy | What it does |
| --- | --- |
| `running` | scales on `vllm_requests_running` |
| `active-pressure` | scales on `vllm_requests_active = waiting + running` |
| `compare` | runs `running`, then `active-pressure`, and writes a side-by-side summary |
| `sweep` | runs `active-pressure` once per `--active-targets` value |

Resilience behavior:

| Mode | What it does |
| --- | --- |
| `healthy` | leaves spot and on-demand serving pools available |
| `spot-unavailable` | withdraws `gpu-serving-spot` before the run and measures on-demand fallback |
| `spot-interruption` | forces burst scale-out onto spot, deletes the live spot-backed burst `NodeClaim`, restores on-demand, and records replacement timing |

Reports are written under `docs/reports/`. See [reports/README.md](reports/README.md)
for the report format, partial-report behavior, and artifact ownership rules.

## Manual Checks

After `./scripts/up`, inspect the platform:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get deployment karpenter -n karpenter
kubectl get pods -n monitoring
kubectl get apiservice v1beta1.custom.metrics.k8s.io
kubectl get ingress -n app -o wide
kubectl get nodepool,ec2nodeclass
```

Open Grafana locally:

```bash
kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000
```

Run the manual GPU smoke manifest:

```bash
kubectl apply -f platform/workloads/validation/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/workloads/validation/gpu-test.yaml
```

## Tear Down

```bash
./scripts/down
```

Common variant:

```bash
./scripts/down -auto-approve
```

Recovery variant for cleanup-eligible orphan CNI ENIs:

```bash
./scripts/down --cleanup-orphan-enis -auto-approve
```

`./scripts/down` removes runtime resources, waits for the ALB to be deleted,
removes active and legacy GPU capacity definitions, uninstalls observability,
uninstalls Karpenter and the NVIDIA device plugin, and then runs
`terraform destroy`.

If the script cannot reconnect to the cluster, it stops before Terraform
destroy and prints the exact fallback destroy command. If destroy fails because
`available` `aws-K8S` or `aws-node` ENIs are still attached to the VPC,
`--cleanup-orphan-enis` deletes only matching cleanup-eligible ENIs and retries
destroy once.

## Dev Boundary

This environment is optimized for iteration, not hardening:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

Production should use private cluster access, tighter allowlists, and a
documented operator access path such as SSM, bastion, or VPN.
