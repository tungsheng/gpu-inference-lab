# Scaling

## Current compute model

The repository now uses a **zero-idle GPU baseline**:

```text
system nodes (managed) -> m7i-flex.large -> controllers and shared services
gpu nodes (dynamic)    -> g4dn.xlarge / g5.xlarge -> vLLM inference pods
```

Isolation rules:

- System nodes are labeled `workload=system`
- Dynamic GPU nodes are labeled `workload=gpu`
- Dynamic GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with both a matching `nodeSelector` and toleration
- The NVIDIA device plugin daemonset targets only `workload=gpu` nodes

The important change from the old baseline is that there is **no managed GPU
node group** anymore. The cluster starts without GPU nodes and Karpenter
launches them only when a pending pod requires accelerator resources.

## Dynamic GPU path

The checked-in Karpenter resources live under `platform/karpenter/`:

- `nodeclass-gpu-serving.yaml`
- `nodepool-gpu-serving.yaml`

The current GPU `NodePool`:

- allows `g4dn.xlarge` and `g5.xlarge`
- keeps capacity on-demand for deterministic milestone validation
- consolidates empty or underutilized nodes after `2m`
- uses the pinned EKS AL2023 NVIDIA AMI release `v20260304`

## Apply flow

Initialize Terraform first:

```bash
terraform -chdir=infra/env/dev init
```

Apply the environment:

```bash
./scripts/dev up
```

That helper now:

1. Applies Terraform for `infra/env/dev`
2. Updates local kubeconfig
3. Installs the AWS Load Balancer Controller
4. Installs metrics-server so HPA has CPU metrics
5. Installs Karpenter and applies the GPU `EC2NodeClass`/`NodePool`
6. Applies the NVIDIA device plugin
7. Applies the sample ingress workload on the system nodes

At that point the cluster is ready for dynamic GPU provisioning, but there
should still be zero GPU worker nodes.

## Baseline verification

After `./scripts/dev up`, verify the control-plane, public edge, and dynamic path:

```bash
kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
kubectl get nodepools
kubectl get daemonset nvidia-device-plugin-daemonset -n kube-system
kubectl get deployment metrics-server -n kube-system
kubectl get deployment karpenter -n karpenter
```

Expected shape:

- at least two `m7i-flex.large` nodes labeled `workload=system`
- zero nodes labeled `karpenter.sh/nodepool=gpu-serving`
- one `NodePool` named `gpu-serving`
- a public inference ingress that resolves before GPU pods are launched

## GPU smoke test

If you want a fast scheduling check before the real serving stack, run:

```bash
kubectl apply -f platform/tests/gpu-test.yaml
kubectl logs -n app gpu-test
```

Expected result: `nvidia-smi` output from the container. When you delete the
pod, the Karpenter GPU node should scale back down.

## Real inference scaling path

The real serving manifest lives at:

```bash
platform/inference/vllm-openai.yaml
```

That manifest adds:

- a vLLM `Deployment`
- a `ClusterIP` service
- a CPU-based `HorizontalPodAutoscaler`

The HPA path is intentional:

- the first replica provisions the first GPU node
- sustained inference traffic can push CPU utilization high enough for the HPA
  to request a second replica
- the second replica requires another GPU, which makes Karpenter launch another
  GPU node

## Measured milestone flow

Run the full milestone validation with:

```bash
./scripts/dev measure
```

The script:

1. Starts from zero GPU nodes
2. Waits for the public inference edge hostname
3. Applies the real inference manifest
4. Measures cold-start milestones until the first replica is Ready
5. Waits for the first successful external completion through the ALB edge
6. Applies the load-test job under `platform/tests/gpu-load-test.yaml`
7. Waits for HPA-driven scale-out to two replicas and two GPU nodes
8. Deletes the load test and waits for one GPU node to consolidate away
9. Deletes the inference workload and waits for all GPU nodes to disappear
10. Writes a Markdown report under `/tmp/` by default

## Version pins

The current pinned baseline is:

- EKS control plane: `1.35`
- System node group AMI type: `AL2023_x86_64_STANDARD`
- System node group release: `1.35.2-20260304`
- Karpenter chart/CRDs: `1.9.0`
- Metrics Server: `v0.8.0`
- GPU node AMI: `amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304`
- NVIDIA device plugin image: `v0.18.1`
- vLLM image: `v0.9.0`
