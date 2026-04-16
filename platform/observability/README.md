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

## Current Custom Metric Limitation

Today the adapter exposes `vllm_requests_running` to the HPA. Prometheus and the
serving dashboard already observe more than that, including waiting requests,
but the autoscaling pipeline has not yet been upgraded to use a capacity-aware
active-pressure metric.

That gap is intentional documentation now, not drift.
