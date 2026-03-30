# Dev Environment Workflow

This repository provisions the dev environment with Terraform and then layers
the Kubernetes controllers and platform manifests on top with shell scripts.

## Prerequisites

- Terraform, AWS CLI, `kubectl`, and `helm`
- AWS credentials for the target account
- The dev environment Terraform at `infra/env/dev`
- The current region `us-west-2`

## Apply Infra + Platform

Initialize Terraform:

```bash
terraform -chdir=infra/env/dev init
```

Apply the environment:

```bash
./scripts/dev up
```

Common variants:

```bash
./scripts/dev up -auto-approve
./scripts/dev up -var-file=dev.tfvars
```

What `./scripts/dev up` does:

1. Runs `terraform -chdir=infra/env/dev apply`
2. Updates local kubeconfig
3. Installs the AWS Load Balancer Controller
4. Installs metrics-server from the pinned upstream release
5. Installs Karpenter and applies the GPU `EC2NodeClass`/`NodePool`
6. Applies the NVIDIA device plugin
7. Ensures the `app` namespace exists
8. Applies the sample ALB-backed echo app

The apply helper is intentionally strict. It still rejects `-target`,
`-refresh-only`, and `-destroy` so it does not run the post-apply Kubernetes
workflow after a partial Terraform operation.

## Verify the ready state

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get deployment metrics-server -n kube-system
kubectl get deployment karpenter -n karpenter
kubectl get nodepools
kubectl get ingress -n app -o wide
```

Expected result:

- system nodes are present
- Karpenter is Ready
- the ALB ingress is present
- there are zero GPU worker nodes until a GPU pod is applied

## Run the milestone flow

The easiest end-to-end validation is:

```bash
./scripts/dev measure
```

That script applies the real vLLM serving manifest, runs the checked-in load
test, waits for scale-out and scale-down, and writes a Markdown report to
`/tmp/` unless you pass a different output path.

Example:

```bash
./scripts/dev measure --report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).md
```

Optional Markdown + JSON outputs:

```bash
./scripts/dev measure \
  --report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).md \
  --json-report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).json
```

Useful companion commands:

```bash
./scripts/dev doctor
./scripts/dev status
./scripts/dev status --verbose
```

## Manual GPU checks

Smoke-test pod:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/tests/gpu-test.yaml
```

Real serving stack:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
kubectl get pods -n app -w
kubectl delete -f platform/inference/vllm-openai.yaml
```

## Destroy Infra + Platform

Destroy the environment with:

```bash
./scripts/dev down
```

Common variant:

```bash
./scripts/dev down -auto-approve
```

The destroy helper:

1. Deletes the sample ingress so the ALB can be removed cleanly
2. Deletes the sample app workload
3. Deletes the GPU smoke test, load test, and inference workload if present
4. Deletes the Karpenter `NodePool`/`EC2NodeClass`
5. Waits for Karpenter-managed GPU nodes to terminate
6. Uninstalls Karpenter
7. Deletes the NVIDIA device plugin
8. Deletes the app namespace
9. Uninstalls the AWS Load Balancer Controller
10. Runs `terraform -chdir=infra/env/dev destroy`

## Recovery / Partial Teardown

If the EKS cluster is already gone or intentionally unreachable:

```bash
SKIP_K8S_CLEANUP=1 ./scripts/dev down
```

Use that only when the Kubernetes-managed resources are already removed or no
longer need cleanup.
