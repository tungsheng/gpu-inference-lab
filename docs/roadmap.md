# Roadmap

Priority list for stronger architecture recommendations.

## Current State

The lab runs a real EKS/vLLM inference path, scales GPU capacity with Karpenter,
compares HPA policies, runs focused experiments, and curates evidence for
admission behavior and long-context KV-cache saturation.

## Priorities

| Priority | Goal | Done when |
| --- | --- | --- |
| Recommendation model | make architecture output explicit | workload inputs map to supported, partial, or rejected patterns with evidence links |
| Evidence matrices | make experiment results comparable | batching, request-pattern, prefill/decode, and cost matrices have curated summaries |
| Queue precision | improve autoscaling and admission decisions | queueing delay, prefill time, decode time, and client timeout behavior are separated |
| GPU efficiency | compare useful work across serving and capacity shapes | scheduler, node-size, placement, cost, latency, and failure-rate comparisons are captured |
| Quantization decision path | prove when FP4 is worth selecting | BF16, NVFP4, and SmoothQuant results include accuracy, memory, latency, throughput, serving cost, and build cost |
| Production boundary | separate lab evidence from production requirements | private access, credentials, cloud-native spot interruption handling, and shared-account teardown are documented |

## Known Limits

- The active environment is dev-oriented and keeps the EKS API public.
- Queue wait is derived from waiting depth over completion rate, not a dedicated
  queue-wait histogram.
- Active-pressure target recommendations are not yet proven.
- GPU efficiency is measured for the current one-pod-per-GPU shape, but the repo
  does not yet compare multiple packing shapes or node sizes.
- Spot interruption testing deletes a live `NodeClaim`; it does not consume
  cloud-native interruption notices.
- Several experiment result summaries are still templates.
