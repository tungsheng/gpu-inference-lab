# platform/observability

This directory contains the observability assets used by the default scripted
workflow.

## What Lives Here

- `kube-prometheus-stack-values.yaml`: Prometheus, Grafana, kube-state-metrics,
  and cluster metrics configuration
- `prometheus-adapter-values.yaml`: custom-metrics API rule configuration
- `vllm-podmonitor.yaml`: vLLM scrape target
- `karpenter-podmonitor.yaml`: Karpenter scrape target
- `dcgm-exporter.yaml`: GPU utilization exporter and `ServiceMonitor`
- `pushgateway.yaml`: experiment summary metric sink
- `dashboards/*.yaml`: Grafana dashboards imported through the sidecar

## How The Repo Uses It

`./scripts/up` installs this stack by default so the repo can treat
observability as part of the main platform story rather than a manual add-on.

`./scripts/evaluate` depends on it for:

- HPA metric preflight through Prometheus Adapter
- latency, TTFT, throughput, and queue-related metrics
- GPU utilization visibility through DCGM exporter
- experiment summary metrics pushed to Pushgateway
- Grafana experiment summaries grouped by both `profile` and `policy`

## Current Custom Metric Surface

Today the adapter exposes both autoscaling metrics:

- `vllm_requests_running`
- `vllm_requests_active`, computed from `max_over_time(running[1m]) + max_over_time(waiting[1m])`

That means the repo can compare the original running-request HPA against the
new active-pressure policy without changing the serving deployment itself.

## Current Limitation

The main observability gap is now queue precision, not signal availability. The
repo still uses p95 TTFT as a v1 queue/TTFT proxy because it does not yet scrape
a dedicated queue-wait histogram.
