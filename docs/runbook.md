# Runbook

Command guide for running the lab. Use [Decision engine](decision-engine.md) to
choose what to measure and [Evidence](evidence.md) to read current conclusions.

## Prerequisites

Local catalog commands need the repository plus `jq` and `python3`: `replay` and
`summarize-reports` read committed evidence with `jq`, and `validate` checks it
against the report schema with `python3`. Live runs also need Terraform, AWS
CLI, `kubectl`, `helm`, `curl`, AWS credentials, and access to `us-west-2`.

Run local tests at any point:

```bash
./test/run.sh
```

## Command Chooser

| Need | Command |
| --- | --- |
| Inspect experiment definitions | `./scripts/experiment list` |
| Validate catalog contracts, serving images, and curated evidence | `./scripts/experiment validate` |
| Re-render an evaluation readout offline | `./scripts/evaluate render-report --record <record>` |
| Show one experiment | `./scripts/experiment show kv-cache` |
| Render a KV cache timeline demo | `./scripts/kv-observe demo --output /tmp/kv-cache-observatory.html` |
| Bring up the dev platform | `./scripts/up` |
| Prove cold start from zero GPU nodes | `./scripts/verify` |
| Run the default burst baseline | `./scripts/evaluate --profile zero-idle` |
| Compare HPA policies | `./scripts/evaluate --profile warm-1 --policy compare --active-target 6` |
| Sweep active-pressure targets | `./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8` |
| Run one experiment case | `./scripts/experiment run --experiment kv-cache --case prompt-512-output-100 --profile default` |
| Run one streaming case | `./scripts/experiment run-stream --experiment prefill-decode --case prefill-heavy --profile default --samples 5` |
| Inspect failure drills | `./scripts/failure list` |
| Dry-run a failure drill | `./scripts/failure run --scenario spot-interruption --mitigation ondemand-fallback --dry-run` |
| Tear down normally | `./scripts/down` |

## Local Rendering

Render-only commands do not require AWS or collect measurements.

```bash
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-load.yaml

./scripts/experiment render-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --output /tmp/prefill-stream.yaml

./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile long-context \
  --output /tmp/vllm-long-context.yaml

./scripts/experiment render-report \
  --experiment cost \
  --case steady-cost-efficiency \
  --profile optimized-batched

./scripts/experiment summarize-reports --experiment kv-cache

./scripts/kv-observe preflight \
  --experiment kv-cache-observatory \
  --profile modern-vllm-0221
```

## Bring Up

```bash
./scripts/up
./scripts/up -auto-approve
./scripts/up -var-file=dev.tfvars
```

Expected state after `./scripts/up`:

- system nodes are present and labeled `workload=system`
- Prometheus, Grafana, the custom metrics API, and Karpenter are Ready
- the inference ingress has a hostname
- GPU node count is still `0`

### Edge Exposure

The inference ALB serves an unauthenticated OpenAI-compatible API over plain
HTTP, so the listener is never created without an explicit source range. By
default it is restricted to the public IP of the machine that ran the command:

```bash
# restricted to this machine (default)
./scripts/up

# a fixed range, for example an office egress block
GPU_INFERENCE_INBOUND_CIDRS=203.0.113.0/24 ./scripts/up

# private ALB with no internet listener
GPU_INFERENCE_INGRESS_SCHEME=internal GPU_INFERENCE_INBOUND_CIDRS=10.0.0.0/8 ./scripts/up
```

`./scripts/up` prints the range it resolved. `./scripts/evaluate` re-renders the
ingress the same way, so set the same variable for both. Opening the endpoint to
`0.0.0.0/0` requires writing it out explicitly and prints a warning.

If your public IP changes mid-session, re-render the edge rather than editing
the ingress by hand:

```bash
GPU_INFERENCE_INBOUND_CIDRS=auto ./scripts/evaluate --profile zero-idle
```

See [platform/inference](../platform/inference/README.md) for the full contract.

## Cold Start

```bash
./scripts/verify
```

This applies the vLLM deployment, waits for one GPU node and one Ready replica,
checks public `/v1/completions`, deletes the deployment, and waits for zero GPU
nodes.

## Burst Evaluations

```bash
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4
./scripts/evaluate --profile warm-1 --policy compare --active-target 6
./scripts/evaluate --profile warm-1 --policy compare --compare-order active-pressure,running --active-target 6
./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8
./scripts/evaluate --profile zero-idle --resilience spot-unavailable
./scripts/evaluate --profile zero-idle --resilience spot-interruption
```

Evaluation reports are written under `docs/reports/`. A report may be partial
if final Prometheus or DCGM collection fails after timeline or cost data is
captured.

## Focused Experiments

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default

./scripts/experiment run-stream \
  --experiment prefill-decode \
  --case prefill-heavy \
  --profile default \
  --samples 5

./scripts/experiment run \
  --experiment kv-cache-observatory \
  --case shared-system-prompt \
  --profile modern-vllm-0221-prefix
```

The runner applies rendered serving and client manifests, waits for completion,
writes Markdown and JSON reports under `docs/reports/`, and cleans up rendered
resources unless `--preserve-serving` or `--preserve-load` is set.

KV Cache Observatory reports add nullable `results.kv_cache` fields. Missing
block, eviction, or reload fields are expected until vLLM metrics or KV events
expose that signal for the selected serving path.

## Failure Drills

Failure drills combine a named scenario, mitigation, workload, and recovery
gate:

```bash
./scripts/failure list
./scripts/failure show scenario spot-interruption
./scripts/failure preflight --scenario spot-interruption --mitigation ondemand-fallback
./scripts/failure run --scenario spot-interruption --mitigation ondemand-fallback --dry-run
./scripts/failure matrix --suite capacity-recovery --dry-run
```

Capacity drills delegate to `./scripts/evaluate` so resilience reports keep the
same timeline, capacity-type, cost, and metric fields. Admission drills delegate
to `./scripts/experiment run`. Pod and GPU-node drills use built-in `kubectl`
injectors and write compact Markdown/JSON recovery reports under
`docs/reports/`.

## Watch A Live Run

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,karpenter.sh/nodepool,karpenter.sh/capacity-type -w
```

Grafana access:

```bash
kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000
```

Manual GPU smoke:

```bash
kubectl apply -f platform/workloads/validation/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/workloads/validation/gpu-test.yaml
```

## Tear Down

```bash
./scripts/down
./scripts/down -auto-approve
./scripts/down --cleanup-orphan-network-dependencies -auto-approve
./scripts/down --cleanup-orphan-enis -auto-approve
./scripts/down --skip-orphan-network-cleanup -auto-approve
./scripts/down --terraform-only -auto-approve
```

Normal teardown automatically retries once after deleting cleanup-eligible
available CNI ENIs and owned orphan EKS node security groups when Terraform
destroy fails on a VPC dependency. Use `--skip-orphan-network-cleanup` for a
diagnostic-only failure, and use `--terraform-only` only after cluster cleanup
has completed or the API is gone.
