# Scaling

## Current Compute Model

The repository keeps a **zero-idle serving baseline** and a separate
**warm-node experiment profile**:

```text
system nodes        -> m7i-flex.large              -> controllers and shared services
gpu-serving nodes   -> g4dn.xlarge / g5.xlarge    -> default elastic serving path
warm placeholder    -> tiny Deployment in app     -> keeps one gpu-serving node alive
```

Isolation rules:

- system nodes are labeled `workload=system`
- GPU nodes are labeled `workload=gpu`
- GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with both a matching `nodeSelector` and toleration
- the NVIDIA device plugin daemonset targets only `workload=gpu` nodes

There is still **no managed GPU node group**. Karpenter owns GPU capacity.

## Default Scripted Path

`./scripts/up` prepares the control plane and observability layer, but it does
not apply the inference deployment.

Expected shape after `./scripts/up`:

- at least two `m7i-flex.large` nodes labeled `workload=system`
- zero nodes labeled `workload=gpu`
- Prometheus, Grafana, and the custom metrics API are Ready
- one `NodePool` named `gpu-serving`
- a public inference ingress that resolves before GPU pods are launched

## Scale-Out Proof Path

`./scripts/evaluate` makes the autoscaling path part of the real workflow:

- applies `platform/inference/vllm-openai.yaml`
- applies `platform/inference/hpa.yaml`
- runs `platform/tests/gpu-load-test.yaml`
- waits for `vllm_requests_running` to drive HPA desired replicas to `2`
- waits for a second `NodeClaim`, second GPU node, and second Ready replica

That makes the HPA an exercised part of the workflow instead of a checked-in
manifest that users must remember to wire up themselves.

## Warm Profile

`./scripts/evaluate --profile warm-1` applies
`platform/tests/gpu-warm-placeholder.yaml` before the vLLM deployment. The
placeholder tolerates the GPU taint, selects the `gpu-serving` labels, and
keeps one dynamic serving node alive without consuming the GPU.

It exists to compare:

- zero idle cost with slower first response
- one warm GPU node with lower latency but higher idle spend

The script removes the warm placeholder at the end of the run so the
environment returns to zero GPU nodes after reporting.

## Version Pins

- EKS control plane: `1.35`
- system node group AMI type: `AL2023_x86_64_STANDARD`
- system node group release: `1.35.2-20260304`
- Karpenter chart/CRDs: `1.9.0`
- kube-prometheus-stack chart: `82.18.0`
- Prometheus Adapter chart: `5.2.0`
- GPU node AMI: `amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304`
- NVIDIA device plugin image: `v0.18.1`
- vLLM image: `v0.9.0`
