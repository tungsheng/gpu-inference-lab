# Dev Environment Workflow

This repository supports one active environment at `infra/env/dev`.

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
5. Installs Prometheus, Grafana, Prometheus Adapter, dashboards, and GPU metrics exporters
6. Installs Karpenter CRDs and controller
7. Applies the GPU `EC2NodeClass` and `NodePool`
8. Applies the NVIDIA device plugin
9. Ensures the `app` namespace exists
10. Applies the inference service and public ingress
11. Waits for the ingress hostname and prints the public URL

Expected result:

- system nodes are present
- Prometheus, Grafana, and the custom metrics API are Ready
- Karpenter is Ready
- the public inference ingress has a hostname
- there are still zero GPU worker nodes until a GPU workload is applied

## Run The Cold-Start Smoke Test

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

## Run The Load-Aware Evaluation

Compare the zero-idle baseline:

```bash
./scripts/evaluate --profile zero-idle
```

Compare the one-warm-node profile:

```bash
./scripts/evaluate --profile warm-1
```

The evaluate flow:

1. Confirms the public edge and custom metrics API are ready
2. Applies the vLLM deployment and HPA
3. Waits for the first replica and first successful public response
4. Runs the checked-in k6 load job
5. Waits for HPA desired replicas to reach `2`
6. Waits for a second `NodeClaim`, second GPU node, and second Ready replica
7. Waits for the burst to complete and then scale back in
8. Cleans up the workload and returns the cluster to zero GPU nodes
9. Writes Markdown and JSON reports under `docs/reports/`

## Manual Checks

Watch the platform after `./scripts/up`:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get deployment karpenter -n karpenter
kubectl get pods -n monitoring
kubectl get apiservice v1beta1.custom.metrics.k8s.io
kubectl get ingress -n app -o wide
```

Open Grafana:

```bash
kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000
```

Run a manual GPU smoke test:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/tests/gpu-test.yaml
```

## Dev Access Boundary

The dev environment intentionally keeps a public EKS API endpoint so local
iteration stays simple. Treat that as a dev-only choice.

The production direction should be:

- private endpoint access
- SSM, bastion, or VPN-based cluster administration
- tighter public-access CIDR controls

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
3. Deletes load-test, HPA, ingress, service, and deployment resources
4. Waits for the ALB to disappear
5. Deletes the warm and serving GPU `NodePool` resources plus the `EC2NodeClass`
6. Removes the observability stack
7. Uninstalls Karpenter and the NVIDIA device plugin
8. Runs `terraform -chdir=infra/env/dev destroy`

If the script cannot reach the cluster, it stops before `terraform destroy` and
prints the exact fallback destroy command to run manually.
