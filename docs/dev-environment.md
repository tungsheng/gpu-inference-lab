# Dev Environment Workflow

This repository has one active environment: `infra/env/dev`. The dev workflow
is intentionally opinionated:

1. bring up the cluster and platform services
2. prove the cold-start path with `./scripts/verify`
3. measure burst behavior with `./scripts/evaluate`
4. tear the environment down cleanly

## Prerequisites

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- access to `us-west-2`

## Happy Path

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
./scripts/down
```

Run the local shell tests at any point with:

```bash
./test/run.sh
```

## Bring The Environment Up

```bash
./scripts/up
```

Common variants:

```bash
./scripts/up -auto-approve
./scripts/up -var-file=dev.tfvars
```

`./scripts/up` performs the full platform bootstrap:

1. runs `terraform init` and `terraform apply` in `infra/env/dev`
2. loads cluster outputs and updates local kubeconfig
3. installs the AWS Load Balancer Controller
4. installs Prometheus, Grafana, Prometheus Adapter, Pushgateway, dashboards,
   and GPU exporters
5. installs Karpenter CRDs and controller
6. applies the shared GPU `EC2NodeClass` and both serving `NodePool`s
7. applies the NVIDIA device plugin
8. ensures the `app` namespace exists
9. applies the public inference service and ingress
10. waits for the ingress hostname and prints the public URL

Expected state after `./scripts/up`:

- system nodes are present and labeled `workload=system`
- Prometheus, Grafana, and the custom metrics API are Ready
- Karpenter is Ready
- the public inference ingress has a hostname
- GPU node count is still `0`

## Prove The Cold-Start Path

```bash
./scripts/verify
```

`./scripts/verify` is the fastest proof that the platform works end to end:

1. applies only `platform/inference/vllm-openai.yaml`
2. waits for the first GPU node and first Ready replica
3. retries the public `/v1/completions` path until it gets a `200`
4. deletes the deployment
5. waits for GPU capacity to return to `0`
6. prints timing for first node, Ready replica, first response, and cleanup

Use this path when you want to validate:

- GPU provisioning from a zero-idle baseline
- vLLM startup and readiness
- public ingress routing
- cleanup back to zero GPU nodes

## Run The Burst Evaluation

Zero-idle baseline:

```bash
./scripts/evaluate --profile zero-idle
```

Capacity-aware policy on the same zero-idle baseline:

```bash
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
```

Warm baseline compare:

```bash
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
```

The evaluation workflow is the deeper platform exercise:

1. confirms the public edge and custom metrics API are available
2. applies the vLLM deployment
3. waits for the first Ready replica and first successful public response
4. preflights the selected custom metric and applies the matching HPA
5. runs the checked-in k6 burst job from `platform/tests/gpu-load-test.yaml`
6. waits for HPA desired replicas to reach `2`
7. waits for the second serving `NodeClaim`, second GPU node, and second Ready
   replica
8. waits for the burst to finish and scale back in
9. deletes the workload and profile-specific warm capacity, or restores the
   warm baseline between policy runs in compare mode
10. collects Prometheus and DCGM metrics and writes per-policy plus optional
    compare reports

Profile behavior:

| Profile | Baseline | What it measures |
| --- | --- | --- |
| `zero-idle` | zero GPU nodes before the run | lowest idle cost, highest cold-start penalty |
| `warm-1` | one on-demand serving node held by `gpu-warm-placeholder` | lower first-response latency, higher idle spend |

Policy behavior:

| Policy | What it does |
| --- | --- |
| `running` | preserves the original HPA on `vllm_requests_running` |
| `active-pressure` | uses `vllm_requests_active = waiting + running` with a configurable `--active-target` |
| `compare` | runs `running` first, then `active-pressure`, and emits a side-by-side compare report |

Reports are written to:

- single policy: `docs/reports/evaluate-<profile>-<policy>-<timestamp>.md`
- single policy: `docs/reports/evaluate-<profile>-<policy>-<timestamp>.json`
- compare mode: the two per-policy artifacts plus
  `docs/reports/evaluate-<profile>-compare-<timestamp>.md` and `.json`

Those reports capture:

- selected policy, HPA metric name, and HPA target average value
- timeline events for node launch, readiness, scale-out, scale-in, and cleanup
- p95 request latency and p95 time to first token as the queue/TTFT proxy
- peak waiting requests and peak active requests
- generation throughput
- average and max GPU utilization
- peak serving `NodeClaim` count, split by capacity type
- estimated serving GPU cost for the run

## Manual Checks

After `./scripts/up`, inspect the platform with:

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
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/tests/gpu-test.yaml
```

## Tear The Environment Down

```bash
./scripts/down
```

Common variant:

```bash
./scripts/down -auto-approve
```

`./scripts/down` performs the inverse lifecycle:

1. runs `terraform init` in `infra/env/dev`
2. reconnects to the cluster from Terraform outputs
3. removes the load job, warm placeholder, HPA, ingress, service, and vLLM
   deployment
4. waits for the ALB to be deleted
5. removes the legacy warm `NodePool`, both serving `NodePool`s, and the shared
   GPU `EC2NodeClass`
6. uninstalls the observability stack
7. uninstalls Karpenter and the NVIDIA device plugin
8. runs `terraform destroy`

If the script cannot reconnect to the cluster, it stops before Terraform
destroy and prints the exact fallback destroy command.

## Dev Boundary

This environment is optimized for iteration, not hardening. In particular, the
EKS API stays public:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

Treat that as a dev-only choice. Production direction should include private
cluster access, tighter allowlists, and a documented SSM, bastion, or VPN-based
administration path.
