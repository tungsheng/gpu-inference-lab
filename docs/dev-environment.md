# Dev Environment Workflow

This repository manages the AWS infrastructure for the dev environment with Terraform and then layers Kubernetes resources on top with shell scripts.

## Prerequisites

- Terraform, AWS CLI, `kubectl`, and `helm` must be installed.
- AWS credentials must be configured for the target account.
- The dev environment Terraform lives in `infra/env/dev`.
- The current dev environment is configured for `us-west-1`.

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
3. Installs the AWS Load Balancer Controller with Helm.
4. Waits for the controller deployment and webhook to become ready.
5. Applies the sample app deployment, service, and ingress from `platform/test-app`.

Useful verification commands:

```bash
kubectl get pods -n kube-system
kubectl get all -n app
kubectl get ingress -n app -o wide
```

When the ingress is ready, the `ADDRESS` field should contain an AWS ALB hostname in `us-west-1`.

Use `./scripts/apply-dev.sh` for full environment apply. For targeted Terraform operations, run `terraform -chdir=infra/env/dev apply ...` directly so you do not trigger the Kubernetes post-apply workflow accidentally.

`./scripts/apply-dev.sh` also rejects `-destroy`. Use `./scripts/destroy-dev.sh` for teardown.

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
4. Deletes the sample app service, deployment, and namespace.
5. Uninstalls the AWS Load Balancer Controller Helm release and deletes its service account.
6. Runs `terraform -chdir=infra/env/dev destroy`.

This ordering matters. The ALB is not a Terraform resource in this repository; it is created indirectly by the Kubernetes ingress. Deleting the ingress before Terraform destroy avoids leaving load balancer dependencies behind in the VPC.

Use `./scripts/destroy-dev.sh` for full environment teardown only. For targeted Terraform destroys, run `terraform -chdir=infra/env/dev destroy ...` directly.

## Recovery / Partial Teardown

If the EKS cluster is already gone or intentionally unreachable, you can skip the Kubernetes cleanup and only run Terraform destroy:

```bash
SKIP_K8S_CLEANUP=1 ./scripts/destroy-dev.sh
```

In this mode, only Terraform is required locally.

Use that only when you are sure the Kubernetes-managed resources are already removed or no longer need cleanup.
