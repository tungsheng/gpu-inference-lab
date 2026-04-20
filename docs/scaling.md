# Scaling

## Current Compute Model

The repo now has a clear mixed-capacity serving story:

| Component | Capacity type | Role | Notes |
| --- | --- | --- | --- |
| system managed node group | on-demand | controllers and shared services | `m7i-flex.large`, always present |
| `gpu-serving-ondemand` | on-demand | warm baseline and fallback serving path | weight `10` |
| `gpu-serving-spot` | spot | preferred burst serving path | weight `50` |
| `gpu-warm-placeholder` | on-demand | keeps one serving node alive for `warm-1` | no GPU request |

Key properties:

- system nodes are labeled `workload=system`
- GPU nodes are labeled `workload=gpu`
- GPU nodes are tainted `gpu=true:NoSchedule`
- GPU workloads opt in with both a matching `nodeSelector` and toleration
- both serving `NodePool`s share the same GPU `EC2NodeClass`
- there is no managed GPU node group

## Default Baseline

After `./scripts/up`, the cluster should have:

- system nodes available
- `gpu-serving-ondemand` and `gpu-serving-spot` registered and Ready
- the NVIDIA device plugin and observability stack running
- a public inference ingress hostname
- zero active GPU nodes

That is the intended starting point. GPU cost should appear only when a GPU
workload is applied.

## What `verify` Exercises

`./scripts/verify` is the cold-start proof:

- applies the vLLM deployment only
- waits for one GPU node
- waits for one Ready replica
- proves one successful public completion
- removes the deployment and waits for zero GPU nodes again

This path answers whether the zero-idle story works at all.

## What `evaluate` Exercises

`./scripts/evaluate` is the burst-scale experiment:

- applies the same vLLM deployment
- waits for the chosen custom-metrics pipeline
- applies the matching HPA policy
- runs the checked-in k6 burst job
- waits for desired replicas to hit `2`
- waits for a second serving `NodeClaim`, second GPU node, and second Ready
  replica
- waits for scale-in and cleanup
- writes per-policy, compare, or sweep reports with timing, utilization,
  derived queue wait, and cost fields
- can also withdraw the preferred spot `NodePool` for the run through
  `./scripts/evaluate --resilience spot-unavailable` and report the resulting
  on-demand fallback path plus GPU node zones

This path answers whether the control loop can add capacity fast enough to
handle bursty inference traffic.

## Current Autoscaling Signals

Today the repo supports two HPA policies:

| Policy | Metric | Target type | Default target | Replica range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `running` | `vllm_requests_running` | pod average value | `128` | `1` to `2` | preserve the original admitted-work baseline |
| `active-pressure` | `vllm_requests_active` | pod average value | `4` | `1` to `2` | scale from `waiting + running` pressure |

That is a meaningful milestone because it proves:

- Prometheus is scraping real vLLM metrics
- Prometheus Adapter is exposing both autoscaling metrics
- the HPA can act on either metric without changing the serving deployment
- `./scripts/evaluate --policy compare` can run both policies against the same
  profile and emit a side-by-side summary
- `./scripts/evaluate --policy sweep --active-targets ...` can calibrate the
  active-pressure target across multiple runs and emit a recommendation summary

## Why `warm-1` Matters

`./scripts/evaluate --profile warm-1` applies the lightweight warm placeholder
before the real inference deployment. That keeps one on-demand serving node
alive so the experiment can isolate the tradeoff between:

- lower idle cost and slower first response
- higher idle cost and faster first response

In compare mode, the workflow restores that warm baseline between the two
policy runs and then removes it at the very end so the environment still
returns to zero GPU nodes after reporting.

## Current Resilience Direction

Milestone 11 has started with a degraded-capacity experiment:

- `./scripts/evaluate --resilience spot-unavailable` deletes the preferred
  `gpu-serving-spot` `NodePool` for the run
- the burst still scales from one to two replicas, but the second GPU node is
  expected to come from `gpu-serving-ondemand`
- reports now call out the resilience mode, fallback outcome, and first/second
  GPU availability zones so capacity scarcity is easier to reason about

The next slice inside this milestone is true interruption handling:

- inject a live spot-node loss during the burst instead of only withdrawing the
  spot pool beforehand
- measure replacement time and whether the second ready replica recovers on
  on-demand capacity
- keep pushing AZ placement and degraded-capacity visibility into the reports

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
