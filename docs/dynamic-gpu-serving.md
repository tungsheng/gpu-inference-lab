# Dynamic GPU Serving Path

This doc summarizes the current serving milestone. For the runnable workflow,
use [dev-environment.md](dev-environment.md).

## What The Repo Now Proves

- cold-start serving from zero GPU nodes
- load-aware scale-out to a second replica and second GPU node
- operator-grade visibility into latency, queue depth, and GPU utilization

## Where The Pieces Live

- `platform/inference/` contains the vLLM deployment, service, ingress, and HPA
- `platform/karpenter/` contains the serving and warm-profile GPU capacity manifests
- `platform/observability/` contains Prometheus, Grafana, Prometheus Adapter, dashboards, Pushgateway, and GPU metrics exporters
- `platform/tests/` contains the manual GPU smoke manifest and the burst load job
- `scripts/evaluate` is the report-producing proof path for burst behavior

## What Success Looks Like

- `kubectl get hpa -n app` shows desired replicas increase to `2`
- `kubectl get nodeclaims` shows a second `NodeClaim` during the burst
- `kubectl get nodes -l workload=gpu` grows to two GPU nodes
- the second vLLM replica becomes `Ready`
- the report captures first-response latency, p95 latency, queue depth, GPU utilization, and cost tradeoffs
