# Dev Environment Workflow

This repository manages the AWS infrastructure for the dev environment with Terraform and then layers Kubernetes resources on top with shell scripts.

## Prerequisites

- Terraform, AWS CLI, `kubectl`, and `helm` must be installed.
- AWS credentials must be configured for the target account.
- The dev environment Terraform lives in `infra/env/dev`.
- The current dev environment is configured for `us-west-2`.

## Apply Infra + Dev

Initialize Terraform first:

```bash
terraform -chdir=infra/env/dev init
```

Apply the dev environment:

```bash
./scripts/apply-dev.sh
```

Common variants:

```bash
./scripts/apply-dev.sh -auto-approve
./scripts/apply-dev.sh -var-file=dev.tfvars
```

What `./scripts/apply-dev.sh` does:

1. Runs `terraform -chdir=infra/env/dev apply`.
2. Updates local kubeconfig for the EKS cluster.
3. Applies the AWS Load Balancer Controller CRDs and installs the pinned Helm chart (`1.14.0`).
4. Waits for the controller deployment and webhook to become ready.
5. Applies the checked-in NVIDIA device plugin manifest pinned to `v0.18.1` for
   tainted GPU nodes.
6. Applies the sample app deployment, service, and ingress from `platform/test-app`.

`./scripts/apply-dev.sh` is intentionally a full baseline-environment helper.
It rejects `-target` and `-refresh-only` so it does not run the Kubernetes
post-apply workflow after a partial Terraform operation.

The helper applies ALB controller CRDs before `helm upgrade --install`, because
AWS documents that Helm upgrades do not install CRD updates automatically.

Useful verification commands:

```bash
kubectl get pods -n kube-system
kubectl get daemonset nvidia-device-plugin-daemonset -n kube-system
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds -o wide
kubectl get all -n app
kubectl get ingress -n app -o wide
kubectl get nodes -L workload -o wide
```

When the ingress is ready, the `ADDRESS` field should contain an AWS ALB hostname in `us-west-2`.

Use `./scripts/apply-dev.sh` for full environment apply. For targeted Terraform operations, run `terraform -chdir=infra/env/dev apply ...` directly so you do not trigger the Kubernetes post-apply workflow accidentally.

`./scripts/apply-dev.sh` also rejects `-destroy`. Use `./scripts/destroy-dev.sh` for teardown.

Karpenter remains a separate workflow documented in `docs/scaling.md`; the
baseline apply helper does not install it automatically.

The GPU test pod and inference deployment remain manual validation steps:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl apply -f platform/inference/gpu-inference.yaml
```

For the GPU path, also inspect a GPU node and confirm it reports
`Allocatable: nvidia.com/gpu: 1` before treating the environment as ready.

## Destroy Infra + Dev

Destroy the dev environment with the teardown helper:

```bash
./scripts/destroy-dev.sh
```

Common variant:

```bash
./scripts/destroy-dev.sh -auto-approve
```

What `./scripts/destroy-dev.sh` does:

1. Updates local kubeconfig for the EKS cluster.
2. Deletes the sample app ingress so the AWS Load Balancer Controller can remove the ALB.
3. Waits for the ingress resource to disappear and waits for the ALB to be deleted in AWS.
4. Deletes the sample app service and deployment.
5. Deletes GPU smoke-test and inference manifests if they are present.
6. Deletes Karpenter test resources, waits for Karpenter-managed nodes to terminate, and uninstalls Karpenter if it is present.
7. Deletes the checked-in NVIDIA device plugin daemonset.
8. Deletes the app namespace.
9. Uninstalls the AWS Load Balancer Controller Helm release and deletes its service account.
10. Runs `terraform -chdir=infra/env/dev destroy`.

This ordering matters. The ALB is not a Terraform resource in this repository; it is created indirectly by the Kubernetes ingress. Deleting the ingress before Terraform destroy avoids leaving load balancer dependencies behind in the VPC.

Use `./scripts/destroy-dev.sh` for full environment teardown only. For targeted Terraform destroys, run `terraform -chdir=infra/env/dev destroy ...` directly.

## Recovery / Partial Teardown

If the EKS cluster is already gone or intentionally unreachable, you can skip the Kubernetes cleanup and only run Terraform destroy:

```bash
SKIP_K8S_CLEANUP=1 ./scripts/destroy-dev.sh
```

In this mode, only Terraform is required locally.

Use that only when you are sure the Kubernetes-managed resources are already removed or no longer need cleanup. If Terraform outputs are unavailable and `SKIP_K8S_CLEANUP` is not set, the destroy helper now exits instead of silently skipping Kubernetes cleanup.
