# Reports

`./scripts/evaluate` writes experiment output into this directory.

Each run can produce:

- a Markdown summary report
- a JSON report with the same timeline and metric fields

The reports are meant to capture:

- first GPU node timing
- first Ready replica timing
- first public response timing
- HPA and Karpenter scale-out timing
- burst latency, queue depth, throughput, and GPU utilization
- zero-idle versus warm-node cost tradeoffs
