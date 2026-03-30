# GPU Inference Lab

**gpu-inference-lab** is a hands-on AWS project for building a production-style
GPU inference platform on Amazon EKS with:

- Terraform
- Karpenter
- Application Load Balancer
- vLLM model serving
- dynamic GPU worker nodes

The current repo default is an **elastic GPU serving path**:

- managed CPU nodes keep the cluster and ingress components alive
- GPU nodes stay at `0` when idle
- Karpenter launches GPU capacity only when a workload requests
  `nvidia.com/gpu`

## What Is Implemented

Milestones completed so far:

- Milestone 1: AWS networking layer
- Milestone 2: EKS cluster deployment
- Milestone 3: ingress and load balancer integration
- Milestone 4: Karpenter control-plane integration
- Milestone 5: GPU runtime prerequisites
- Milestone 6: dynamic GPU serving path

Milestone 6 adds:

- a Karpenter-managed GPU `EC2NodeClass` and `NodePool`
- a real vLLM inference deployment
- an HPA and checked-in load test for scale-out
- a measurement script for cold start, scheduling, and scale-down timing
- a cost note comparing fixed GPU capacity with dynamic GPU capacity

## Architecture At A Glance

```text
Internet
   |
   v
ALB
   |
   v
Ingress
   |
   +--> sample echo app on managed CPU nodes
   |
   +--> vLLM on Karpenter GPU nodes

EKS cluster
   |
   +--> managed system node group (m7i-flex.large)
   |
   +--> Karpenter GPU NodePool (g4dn.xlarge / g5.xlarge)
          |
          +--> workload=gpu
          +--> gpu=true:NoSchedule
          +--> NVIDIA device plugin
```

## Repository Map

- `infra/env/dev/`: active Terraform environment
- `infra/modules/`: reusable Terraform modules
- `platform/karpenter/`: GPU `EC2NodeClass`, `NodePool`, and service account
- `platform/inference/`: real vLLM serving manifest
- `platform/system/`: cluster-level runtime manifests such as the NVIDIA device plugin
- `platform/test-app/`: sample ALB-backed echo app
- `platform/tests/`: smoke test and load test manifests
- `scripts/`: apply, measurement, and destroy helpers
- `docs/`: architecture, operations, scaling, cost, and workflow notes

## Prerequisites

- Terraform
- AWS CLI
- `kubectl`
- `helm`
- AWS credentials for the target account
- region set up for `us-west-2`

## Quick Start

Initialize Terraform:

```bash
terraform -chdir=infra/env/dev init
```

Apply the dev environment:

```bash
./scripts/dev up
```

Expected post-apply state:

- system nodes are present
- Karpenter is installed
- the GPU `NodePool` exists
- the NVIDIA device plugin is installed
- the sample ingress app is present
- **GPU worker node count is still zero**

That last point is intentional. `./scripts/dev up` makes the cluster
**GPU-ready**, but it does not apply the GPU inference workload. The first GPU
node should appear only after a GPU pod is created.

Run the dynamic GPU serving validation flow:

```bash
./scripts/dev measure
```

Optional custom report path:

```bash
./scripts/dev measure --report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).md
```

Destroy the environment:

```bash
./scripts/dev down
```

Inspect readiness or current cluster state:

```bash
./scripts/dev doctor
./scripts/dev status
./scripts/dev status --verbose
```

Run the local shell checks:

```bash
./test/run.sh
```

## Manual Checks

Verify the cluster after apply:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get deployment metrics-server -n kube-system
kubectl get deployment karpenter -n karpenter
kubectl get nodepools
kubectl get daemonset nvidia-device-plugin-daemonset -n kube-system
kubectl get ingress -n app -o wide
```

Run a quick GPU smoke test:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
kubectl delete -f platform/tests/gpu-test.yaml
```

Apply the real inference workload manually:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
kubectl get pods -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,node.kubernetes.io/instance-type -w
kubectl delete -f platform/inference/vllm-openai.yaml
```

## Key Scripts

- `./scripts/dev up`
  Applies Terraform, updates kubeconfig, installs controllers, applies the GPU
  `EC2NodeClass` and `NodePool`, and deploys the sample echo app.
- `./scripts/dev measure`
  Applies the vLLM workload, drives load, records scale-up and scale-down
  milestones, and writes a Markdown report.
- `./scripts/dev down`
  Removes Kubernetes-side resources in teardown-safe order, then destroys the
  Terraform-managed infrastructure.
- `./scripts/dev doctor`
  Verifies local prerequisites, Terraform outputs, and core cluster resources
  needed for the dynamic GPU path. Use `--json` for machine-readable output.
- `./scripts/dev status`
  Prints a compact readiness-oriented cluster snapshot. Use `--verbose` for the
  detailed kubectl tables or `--json` for machine-readable output.

## Docs

- [Architecture](docs/architecture.md)
- [Dev environment workflow](docs/dev-environment.md)
- [Dynamic GPU serving](docs/dynamic-gpu-serving.md)
- [Operations](docs/operations.md)
- [Scaling](docs/scaling.md)
- [Inference](docs/inference.md)
- [Cost optimization](docs/cost-optimization.md)
- [Networking](docs/networking.md)
- [GPU bin packing](docs/gpu-binpacking.md)
- [Roadmap](docs/roadmap.md)
