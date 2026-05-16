# Roadmap

Priority list for stronger architecture recommendations.

## Current State

The lab runs a real EKS/vLLM inference path, scales GPU capacity with Karpenter,
compares HPA policies, runs focused experiments, and curates evidence for
admission behavior, long-context KV-cache saturation, request-pattern effects,
and small-request useful-work cost. The current operator-facing readout lives in
[Recommendations](recommendations.md).

## Priorities

| Priority | Goal | Done when |
| --- | --- | --- |
| Recommendation model | harden architecture output | workload inputs map to supported, partial, or rejected patterns with evidence links and stay current as new runs land |
| Evidence matrices | make experiment results comparable | remaining matrices have curated summaries, graph artifacts, SLO notes, and boundary notes |
| Queue precision | improve autoscaling and admission decisions | queueing delay, prefill time, decode time, and client timeout behavior are separated |
| GPU efficiency | compare useful work across serving and capacity shapes | scheduler, node-size, placement, cost, latency, and failure-rate comparisons are captured |
| Quantization decision path | prove when FP4 is worth selecting | BF16, NVFP4, and SmoothQuant results include accuracy, memory, latency, throughput, serving cost, and build cost |
| Production boundary | separate lab evidence from production requirements | private access, credentials, cloud-native spot interruption handling, and shared-account teardown are documented |

## Known Limits

- The active environment is dev-oriented and keeps the EKS API public.
- Non-streaming runs capture k6 HTTP phase timing, including client waiting,
  but queue wait is still not a dedicated server-side histogram.
- Active-pressure target `8` is the current zero-idle sweep recommendation, but
  the sweep was underutilized and does not prove an optimal production target.
- GPU efficiency is measured for the current one-pod-per-GPU shape, but the repo
  does not yet compare multiple packing shapes or node sizes.
- Spot interruption testing deletes a live `NodeClaim`; it does not consume
  cloud-native interruption notices.
- FP4 result summaries are still pending live Blackwell capacity.
