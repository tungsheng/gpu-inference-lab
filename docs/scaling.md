# Scaling

Scaling in this repo is intentionally small and observable: one vLLM replica can
scale to two replicas, and each replica gets its own GPU-backed pod and serving
node.

## Compute Model

| Component | Capacity type | Role |
| --- | --- | --- |
| managed system node group | on-demand | controllers and shared services |
| `gpu-serving-ondemand` | on-demand | warm baseline and fallback serving path |
| `gpu-serving-spot` | spot | preferred fresh burst capacity |
| `gpu-warm-placeholder` | on-demand | keeps one serving node alive for `warm-1` without consuming a GPU |

Key properties:

- system nodes are labeled `workload=system`
- GPU nodes are labeled `workload=gpu`
- GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with a matching selector and toleration
- both serving `NodePool`s share the same GPU `EC2NodeClass`
- there is no managed GPU node group

After `./scripts/up`, the intended baseline is a ready platform with zero GPU
nodes.

## What Scales

`./scripts/verify` proves cold start:

- applies the vLLM deployment only
- waits for one GPU node
- waits for one Ready replica
- proves one successful public completion
- removes the deployment and waits for zero GPU nodes

`./scripts/evaluate` proves burst scale-out:

- applies the vLLM deployment
- applies the selected HPA policy
- runs the checked-in k6 burst job
- waits for desired replicas to reach `2`
- waits for a second serving `NodeClaim`, GPU node, and Ready replica
- writes Markdown and JSON reports under `docs/reports/`

## HPA Signals

| Policy | Metric | Default target | Replica range |
| --- | --- | ---: | --- |
| `running` | `vllm_requests_running` | `128` | `1` to `2` |
| `active-pressure` | `vllm_requests_active = waiting + running` | `4` | `1` to `2` |

`compare` runs both policies sequentially. `sweep` runs active-pressure once
per configured target and writes a recommendation summary.

## Capacity Profiles

`zero-idle` starts with no GPU nodes. It minimizes idle GPU spend and pays the
full cold-start cost.

`warm-1` keeps one on-demand serving node alive through
`gpu-warm-placeholder`. It improves first-response latency and increases idle
cost.

## Resilience Modes

| Mode | Behavior |
| --- | --- |
| `healthy` | leaves spot and on-demand serving pools available |
| `spot-unavailable` | removes `gpu-serving-spot` before the run so burst scale-out must fall back to on-demand |
| `spot-interruption` | temporarily removes on-demand before burst scale-out, deletes the live spot-backed burst `NodeClaim`, restores on-demand, and measures replacement timing |

The interruption mode is useful for a controlled lab drill, but it is not the
same as consuming a cloud-native spot interruption notice.

## Version Pins

- EKS control plane: `1.35`
- system node AMI type: `AL2023_x86_64_STANDARD`
- system node AMI release: `1.35.2-20260304`
- Karpenter chart and CRDs: `1.9.0`
- kube-prometheus-stack chart: `82.18.0`
- Prometheus Adapter chart: `5.2.0`
- GPU node AMI: `amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304`
- NVIDIA device plugin image: `v0.18.1`
- vLLM image: `v0.9.0`
