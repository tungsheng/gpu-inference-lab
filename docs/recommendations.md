# Recommendations

Operator-facing recommendations distilled from the current evidence. Use this
page after [Decision engine](decision-engine.md) identifies the workload shape,
then follow evidence links for the measured boundary.

## Current Architecture Readout

| Situation | Recommendation | Confidence | Evidence |
| --- | --- | --- | --- |
| Steady homogeneous `512/128` traffic | Keep vLLM dynamic scheduler defaults and batching enabled. | supported | [Batching](../experiments/batching/results.md), [Cost](../experiments/cost/results.md), [Evidence](evidence.md#small-request-scheduler-defaults) |
| Burst small-request traffic | Use batching for useful-work cost, but add admission, autoscaling, or more capacity before claiming latency SLO compliance. | supported | [Cost](../experiments/cost/results.md), [Autoscaling](../experiments/autoscaling/results.md), [Request patterns](../experiments/request-patterns/results.md) |
| Traffic can arrive before a cold model is ready | Put bounded admission in front of the serving path. | supported | [Autoscaling](../experiments/autoscaling/results.md), [Evidence](evidence.md#autoscaling-and-admission) |
| Long-context `8192/300` near `1.15 req/s` or above | Set an explicit admission or concurrency boundary; treat zero failures with high queueing as an SLO miss. | supported | [KV cache](../experiments/kv-cache/results.md), [Evidence](evidence.md#kv-cache-and-long-context) |
| Current g4dn/vLLM `v0.9.0` long-context scheduler caps | Do not use lower `max_num_seqs` or larger `max_num_batched_tokens` as the first fix for the `1.20 req/s` knee. | rejected | [KV cache](../experiments/kv-cache/results.md#scheduler-profile-follow-up-at-120-reqs) |
| Streamed workloads | Track TTFT, inter-token latency, and total latency separately. | supported | [Prefill/decode](../experiments/prefill-decode/results.md), [Evidence](evidence.md#prefill-and-decode-timing) |
| Current g4dn/vLLM `v0.9.0` long-context FP8 KV path | Do not select FP8 KV for `8192/300` unless a newer vLLM image or different GPU backend is under test. | rejected | [KV cache](../experiments/kv-cache/results.md#fp8-kv-cache-probe), [Evidence](evidence.md#fp8-kv-cache-on-current-g4dn-path) |
| Active-pressure HPA target selection | Keep active-pressure HPA in the test matrix, but do not treat target `8` as production-optimal. | partial | [Evidence](evidence.md#active-pressure-hpa-tuning), [Roadmap](roadmap.md) |
| Blackwell FP4 serving | Hold the architecture decision until BF16, NVFP4, and SmoothQuant live results exist. | pending | [FP4](../experiments/fp4/results.md), [Experiment catalog](experiment-catalog.md) |

## Decision Rules

Prefer useful work over raw accepted load. A profile that accepts more requests
but drops work or misses p95/p99 latency should lose to a profile that reports
bounded demand and predictable delivery.

Treat queueing as part of the user-facing result. Long-context runs show that a
case can report zero request failures while still crossing the practical edge
through rising waiting depth and tail latency.

Use client timing as a sanity check, not as proof of server queue delay. The
latest long-context admission rerun shows p95 client waiting equal to p95 request
latency while other client HTTP phases stay near zero, which rules out
client/network overhead for that case but still does not split queue, prefill,
and decode inside vLLM.

Treat traffic shape as a first-class input. Steady, burst, uneven-size, and
spike-to-zero traffic produce different delivery, memory, latency, and active
concurrency behavior on the same serving profile.

Separate production recommendations from lab-safe probes. Underutilized HPA
sweeps, partial reports, missing GPU rollups, or blocked Blackwell capacity can
guide the next run, but they should not become production defaults.

## Next Live Runs

These runs are the shortest path from partial evidence to stronger
recommendations:

| Goal | Run | Promotion gate |
| --- | --- | --- |
| Active-pressure target | Repeat the zero-idle active-pressure sweep under higher offered pressure or a smaller capacity shape. | at least one target reaches the balanced band without missing queue, TTFT, GPU, or cost fields |
| Queue precision | Run the long-context baseline/admission rerun with the new nullable vLLM server-side timing fields. | reports separate queue delay from prefill, decode, TTFT, inter-token, e2e latency, and client timeout behavior |
| Scheduler breadth | Run mixed-size and fairness-oriented scheduler profiles beyond homogeneous `512/128`. | explicit caps beat dynamic defaults on a documented fairness or latency objective |
| GPU efficiency | Compare node size, pod packing, placement, and cost instead of only one pod per GPU. | useful work, failure rate, latency, GPU utilization, and cost are captured for each capacity shape |
| FP4 | Re-run BF16, plain NVFP4, and SmoothQuant when `p6-b200.48xlarge` capacity is available. | accuracy, memory, latency, throughput, serving cost, and build cost are populated for all profiles |
