# platform/observability

This directory contains the observability resources for the production-metrics
milestone:

- `kube-prometheus-stack-values.yaml` for Prometheus, Grafana, node metrics, and
  kube-state-metrics
- `prometheus-adapter-values.yaml` for the custom-metrics API used by the vLLM
  HPA
- `vllm-podmonitor.yaml` for scraping vLLM request and queue metrics
- `karpenter-podmonitor.yaml` for scraping Karpenter controller metrics
- `dcgm-exporter.yaml` for GPU utilization metrics on GPU nodes
- `pushgateway.yaml` for measurement-run summary metrics
- `dashboards/*.yaml` for Grafana dashboards imported by the Grafana sidecar

The stack is installed by `./scripts/dev up` into the `monitoring` namespace and
removed by `./scripts/dev down`.
