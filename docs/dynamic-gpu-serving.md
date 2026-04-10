# Dynamic GPU Serving Path

The current milestone is no longer just “does a GPU pod ever start?”

It now proves three layers together:

- cold-start serving from zero GPU nodes
- load-aware scale-out to a second replica and second GPU node
- operator-grade visibility into latency, queue depth, and GPU utilization

## Deliverables

### 1. Zero-idle serving baseline

Files:

- `platform/karpenter/nodeclass-gpu-serving.yaml`
- `platform/karpenter/nodepool-gpu-serving.yaml`
- `platform/inference/vllm-openai.yaml`

Behavior:

- launches `g4dn.xlarge` or `g5.xlarge`
- keeps the default GPU baseline at zero idle nodes
- serves a real vLLM OpenAI-compatible API

### 2. Real autoscaling path

Files:

- `platform/inference/hpa.yaml`
- `platform/tests/gpu-load-test.yaml`
- `platform/observability/prometheus-adapter-values.yaml`
- `platform/observability/vllm-podmonitor.yaml`

Behavior:

- scales from `1` to `2` replicas on `vllm_requests_waiting`
- turns replica scale-out into a second GPU node through Karpenter
- uses a controlled in-cluster burst to prove the path

### 3. Operator-grade visibility

Files:

- `platform/observability/kube-prometheus-stack-values.yaml`
- `platform/observability/dcgm-exporter.yaml`
- `platform/observability/dashboards/`

Behavior:

- exposes Prometheus and Grafana by default
- captures p95 request latency, queue depth, throughput, and GPU utilization
- captures capacity signals such as HPA replicas and active `NodeClaim` count

### 4. Tradeoff reports

Script:

- `./scripts/evaluate`

Outputs:

- Markdown and JSON reports under `docs/reports/`
- zero-idle versus `warm-1` comparisons
- estimated idle cost per hour and burst cost

## How To Run It

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
```

## What Success Looks Like

- `kubectl get hpa -n app` shows desired replicas increase to `2`
- `kubectl get nodeclaims` shows a second `NodeClaim` during the burst
- `kubectl get nodes -l workload=gpu` grows to two GPU nodes
- the second vLLM replica becomes `Ready`
- the report captures first-response latency, p95 latency, queue depth, and GPU utilization
