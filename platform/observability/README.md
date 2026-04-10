# platform/observability

This directory contains the observability resources used by the default
workflow.

Key pieces:

- `kube-prometheus-stack-values.yaml` for Prometheus, Grafana, node metrics, and
  kube-state-metrics
- `prometheus-adapter-values.yaml` for the custom-metrics API used by the vLLM
  HPA
- `vllm-podmonitor.yaml` for scraping vLLM request and queue metrics
- `karpenter-podmonitor.yaml` for scraping Karpenter controller metrics
- `dcgm-exporter.yaml` for GPU utilization metrics on GPU nodes
- `pushgateway.yaml` for experiment summary metrics
- `dashboards/*.yaml` for Grafana dashboards imported by the Grafana sidecar

`./scripts/up` installs this stack.

`./scripts/evaluate` depends on it to prove:

- queue-depth-driven HPA scale-out
- burst latency and throughput measurements
- GPU utilization and saturation visibility
