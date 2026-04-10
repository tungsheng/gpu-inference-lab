# Dev Environment Workflow

This repository now uses a minimal shell workflow around the single supported
environment at `infra/env/dev`.

## Prerequisites

- Terraform, AWS CLI, `kubectl`, and `helm`
- AWS credentials for the target account
- the current region `us-west-2`

## Bring The Environment Up

```bash
./scripts/up
```

Common variants:

```bash
./scripts/up -auto-approve
./scripts/up -var-file=dev.tfvars
```

What `./scripts/up` does:

1. Runs `terraform -chdir=infra/env/dev init -input=false`
2. Runs `terraform -chdir=infra/env/dev apply`
3. Updates local kubeconfig from Terraform outputs
4. Installs the AWS Load Balancer Controller
5. Installs Karpenter CRDs and controller
6. Applies the GPU `EC2NodeClass` and `NodePool`
7. Applies the NVIDIA device plugin
8. Ensures the `app` namespace exists
9. Applies the inference service and public ingress
10. Waits for the ingress hostname and prints the public URL

Expected result:

- system nodes are present
- Karpenter is Ready
- the public inference ingress has a hostname
- the cluster is GPU-ready
- there are still zero GPU worker nodes until a GPU workload is applied

## Run The Default Verification

```bash
./scripts/verify
```

The verify flow:

1. Applies the deployment-only vLLM manifest
2. Waits for one GPU node to appear
3. Waits for the deployment to become Ready
4. Repeats a public `/v1/completions` request until it gets a `200`
5. Deletes the deployment
6. Waits for the GPU node count to return to zero
7. Prints a short timing summary

## Manual Checks

Watch the platform after `./scripts/up`:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get deployment karpenter -n karpenter
kubectl get nodepools
kubectl get ingress -n app -o wide
```

Run a manual GPU smoke test:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/tests/gpu-test.yaml
```

Exercise the deployment manually:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
kubectl get pods -n app -w
kubectl get nodes -L workload,node.kubernetes.io/instance-type -w
kubectl delete -f platform/inference/vllm-openai.yaml
```

## Tear The Environment Down

```bash
./scripts/down
```

Common variant:

```bash
./scripts/down -auto-approve
```

What `./scripts/down` does:

1. Runs `terraform -chdir=infra/env/dev init -input=false`
2. Reconnects to the cluster from Terraform outputs
3. Deletes the inference ingress, service, and deployment
4. Waits for the ALB to disappear
5. Deletes the GPU `NodePool` and `EC2NodeClass`
6. Uninstalls Karpenter and the NVIDIA device plugin
7. Runs `terraform -chdir=infra/env/dev destroy`

If the script cannot reach the cluster, it stops before `terraform destroy` and
prints the exact fallback destroy command to run manually.
