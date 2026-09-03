# Platform Reference

Implementation facts behind the decision engine. The platform is built for dev
measurement, not production hardening.

## System Shape

| Layer | Components | Purpose |
| --- | --- | --- |
| Infrastructure | Terraform VPC, EKS, Karpenter modules | create the AWS dev environment |
| Edge | AWS Load Balancer Controller, service, ingress | expose OpenAI-compatible `/v1` through a public ALB |
| Serving | vLLM deployment and rendered experiment profiles | run GPU-backed completions |
| Autoscaling | HPA, Prometheus Adapter, vLLM metrics | compare running-request and active-pressure signals |
| Capacity | Karpenter `EC2NodeClass` and GPU `NodePool`s | provision and recycle serving nodes on demand |
| Runtime | NVIDIA device plugin | expose `nvidia.com/gpu` to scheduled workloads |
| Observability | Prometheus, Grafana, Pushgateway, DCGM | drive HPA, dashboards, and reports |

System capacity and serving capacity are separate: managed EKS nodes run
controllers and shared services; Karpenter owns all GPU serving nodes. There is
no managed GPU node group.

## Infrastructure

Active Terraform environment: `infra/env/dev`

| Field | Value |
| --- | --- |
| Region | `us-west-2` |
| Availability zones | `us-west-2b`, `us-west-2d` |
| VPC | `10.0.0.0/16` |
| Public subnets | `10.0.1.0/24`, `10.0.2.0/24` |
| Private subnets | `10.0.11.0/24`, `10.0.12.0/24` |
| EKS version | `1.35` |
| System node group | `m7i-flex.large`, `workload=system` |

Public subnets are tagged for internet-facing load balancers. Private subnets
are tagged for internal load balancers and Karpenter discovery.

## Inference Surface

Default checked-in serving manifest:

| Field | Value |
| --- | --- |
| Image | `vllm/vllm-openai:v0.9.0` |
| Model | `Qwen/Qwen2.5-0.5B-Instruct` |
| Served model name | `qwen2.5-0.5b` |
| Health path | `/health` |
| Container port | `8000` |
| Max model length | `2048` |
| GPU memory utilization | `0.85` |
| GPU request/limit | `nvidia.com/gpu: 1` |

The workload selects `workload=gpu`, tolerates `gpu=true:NoSchedule`, and cannot
land on system nodes.

## Capacity

| NodePool | Capacity | Purpose |
| --- | --- | --- |
| `gpu-serving-ondemand` | on-demand `g4dn.xlarge` or `g5.xlarge` | warm baseline and fallback path |
| `gpu-serving-spot` | spot `g4dn.xlarge` or `g5.xlarge` | preferred fresh burst path |
| `gpu-serving-blackwell` | on-demand `p6-b200.48xlarge` | optional full-instance Blackwell FP4 path |

All GPU pools share the same `EC2NodeClass`, GPU taint, and `workload=gpu`
label. The Blackwell pool adds `gpu-arch=blackwell` for rendered profiles that
request 8 GPUs with tensor parallelism.

`warm-1` keeps one on-demand serving node alive with
`platform/workloads/validation/gpu-warm-placeholder.yaml`; it does not use a
separate warm NodePool.

## Autoscaling

Both HPA policies target `vllm-openai` with `minReplicas: 1` and
`maxReplicas: 2`.

| Policy | Manifest | Metric | Default target |
| --- | --- | --- | ---: |
| `running` | `hpa.yaml` | `vllm_requests_running` | `128` |
| `active-pressure` | `hpa-active-pressure.yaml` | `vllm_requests_active = waiting + running` | `4` |

Apply one HPA policy at a time because both manifests use the same HPA name.
Prefer the evaluation script for policy tests.

## Observability

`./scripts/up` installs:

- kube-prometheus-stack and Grafana dashboards
- Prometheus Adapter custom metrics
- vLLM and Karpenter PodMonitors
- DCGM exporter
- Pushgateway

The main observability gap is queue precision. The repo derives queue wait from
waiting depth over request completion rate; it does not yet scrape a dedicated
queue-wait histogram.

## Cost Scope

Evaluation reports estimate serving GPU cost only. They exclude the EKS control
plane, managed system nodes, NAT Gateway, ALB, storage, data transfer, and price
drift outside checked-in cost tables. FP4 reports separate recurring serving
cost from one-time quantization build cost.

## Version Pins

| Component | Version |
| --- | --- |
| system node AMI release | `1.35.2-20260304` |
| Karpenter chart and CRDs | `1.9.0` |
| kube-prometheus-stack chart | `82.18.0` |
| Prometheus Adapter chart | `5.2.0` |
| GPU node AMI | `amazon-eks-node-al2023-x86_64-nvidia-1.35-v20260304` |
| NVIDIA device plugin | `v0.18.1` |
| default vLLM image | `v0.9.0` |
| Blackwell FP4 vLLM image | `v0.20.1` |

## Dev Boundary

The active environment keeps the EKS API public:

- `endpoint_public_access = true`
- `endpoint_public_access_cidrs = ["0.0.0.0/0"]`

Production requires private cluster access, a documented operator path, and
narrower public CIDR controls.

The inference ALB is narrower than the EKS API. Its listener carries an explicit
`inbound-cidrs` source range chosen at apply time and defaults to the operator
public IP; see [Edge Exposure](../platform/inference/README.md#edge-exposure).
It still terminates plain HTTP with no authentication, so production also
requires TLS and an authenticated path in front of `/v1`.
