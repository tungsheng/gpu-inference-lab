# Scaling

## Current compute model

The repository now runs a split-capacity baseline instead of a system-only
cluster:

```text
system nodes (managed) -> m7i-flex.large -> controllers and shared services
gpu nodes (managed)    -> g4dn.xlarge    -> GPU validation and inference pods
```

Isolation rules:

- System nodes are labeled `workload=system`
- GPU nodes are labeled `workload=gpu`
- GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with both a matching `nodeSelector` and toleration
- The NVIDIA device plugin runs only on `workload=gpu` nodes and tolerates the
  GPU taint

That gives the lab a clear baseline:

- controllers and ingress stay on cheaper CPU capacity
- GPU runtime components land only where they are needed
- the cluster exposes `nvidia.com/gpu` before any real inference workload is
  applied

## Baseline apply flow

The default environment helper now provisions both managed node groups and then
completes the cluster-side prerequisites:

```bash
terraform -chdir=infra/env/dev init
./scripts/apply-dev.sh
```

`./scripts/apply-dev.sh` now:

1. Runs `terraform apply` for `infra/env/dev`
2. Updates local kubeconfig
3. Installs the AWS Load Balancer Controller
4. Applies the checked-in NVIDIA device plugin manifest at
   `platform/system/nvidia-device-plugin.yaml`
5. Waits for GPU nodes to advertise `nvidia.com/gpu`
6. Applies the sample ingress workload under `platform/test-app`

The helper is intentionally strict. If the GPU node group comes up but the
device plugin never exposes GPU allocatable capacity, the script fails instead
of reporting a half-ready environment.

## Baseline verification

After `./scripts/apply-dev.sh`, verify the node split:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
```

Expected shape:

- at least one `m7i-flex.large` node labeled `workload=system`
- at least one `g4dn.xlarge` node labeled `workload=gpu`

Verify the device plugin:

```bash
kubectl get daemonset nvidia-device-plugin-daemonset -n kube-system
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds -o wide
```

Then inspect a GPU node:

```bash
kubectl describe node <gpu-node-name>
```

Look for:

```text
Allocatable:
  nvidia.com/gpu: 1
```

If that line is missing, stop there and fix the GPU runtime path before testing
an inference workload.

## GPU smoke test

The first real validation path is the checked-in GPU pod:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
```

Expected result: `nvidia-smi` output from the container.

That confirms:

- the pod reached the tainted GPU node group
- the device plugin exposed the GPU resource
- the container runtime can see the GPU

## Placeholder inference workload

Once the smoke test passes, you can exercise the placeholder deployment:

```bash
kubectl apply -f platform/inference/gpu-inference.yaml
kubectl get pods -n app -o wide
```

This deployment is not a real inference server yet. It exists to validate the
scheduling contract the future serving stack will depend on:

- `nodeSelector: workload=gpu`
- `gpu=true:NoSchedule` toleration
- `limits.nvidia.com/gpu: 1`

## Destroy flow

The teardown helper understands the full baseline path:

```bash
./scripts/destroy-dev.sh
```

Before Terraform destroy, it now removes:

- the ingress so the ALB can be deleted cleanly
- the sample app service and deployment
- `platform/tests/gpu-test.yaml`
- `platform/inference/gpu-inference.yaml`
- the checked-in NVIDIA device plugin daemonset
- optional Karpenter resources if you installed them separately

That ordering matters because the ALB and GPU runtime resources are created
through Kubernetes rather than directly through Terraform state.

## Version pins

The current pinned baseline is:

- EKS control plane: `1.35`
- System node group AMI type: `AL2023_x86_64_STANDARD`
- System node group release: `1.35.2-20260304`
- GPU node group AMI type: `AL2023_x86_64_NVIDIA`
- GPU node group release: `1.35.2-20260304`
- NVIDIA device plugin image: `v0.18.1`

The repo also keeps an optional Karpenter path pinned to:

- Karpenter chart/CRDs: `1.9.0`
- `EC2NodeClass` alias: `al2023@v20260304`

Those pins are intentional so the lab stays reproducible instead of drifting
whenever upstream recommended images change.

## Optional Karpenter path

Karpenter remains checked in, but it is no longer the baseline compute story.
Use it as a separate experiment after the managed GPU path is working:

- Terraform: `infra/modules/karpenter/`
- Manifests: `platform/karpenter/`
- CPU scale test: `platform/tests/cpu-scale-test.yaml`

That path is useful for proving pod-pending-to-new-node behavior, but the
default apply/destroy helpers are now centered on the fixed system/GPU split.
