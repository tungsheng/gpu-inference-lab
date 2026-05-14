# Decision Engine

Turn one question into one architecture conclusion. A run starts with a workload
hypothesis, produces measured evidence, and ends with a recommendation,
rejection, or documented gap.

## Decision Loop

1. Define the workload: prompt length, output length, traffic pattern, arrival
   rate, streaming mode, and failure tolerance.
2. Choose the serving shape: model, context length, scheduler limits, KV-cache
   settings, capacity profile, and cost scope.
3. Run the smallest experiment that isolates the decision.
4. Check the result against the evidence gate.
5. Promote supported conclusions into [Evidence](evidence.md) or the
   matching `experiments/<name>/results.md`.

Generated reports are inputs. Curated conclusions are the product.

## Inputs

| Input | Examples | Decision pressure |
| --- | --- | --- |
| Workload | `512/128`, `8192/300`, streamed decode-heavy requests | prefill, decode, KV cache, and client timeout pressure |
| SLO | p95/p99 latency, delivery ratio, dropped work | useful work, not raw throughput |
| Serving profile | context length, `max_num_seqs`, batched tokens, KV dtype | concurrency, memory pressure, and tail latency |
| Capacity profile | zero-idle, warm node, spot, on-demand, Blackwell | cost, cold start, availability, and placement risk |
| Admission model | direct, bounded queue, future production queue | shedding, delay, or backpressure under overload |
| Cost model | serving-GPU-only, Capacity Blocks, quantization build cost | comparable cost/performance readout |

## Architecture Patterns

| Pattern | Use when | Evidence required |
| --- | --- | --- |
| Zero-idle plus bounded admission | sparse traffic, cost pressure, clients can wait or retry | cold-start timeline, delivery ratio, p95/p99 latency, queue depth |
| Warm baseline plus active-pressure scaling | first response matters and idle GPU cost is acceptable | compare runs in both orders, second Ready replica timing, burst cost |
| Conservative long-context scheduler | long prompts create rising tail latency near the concurrency knee | rate sweep, waiting/running/active depth, delivery ratio, GPU memory |
| Quantized model path | memory or cost savings might offset accuracy or throughput risk | accuracy recovery, p95/p99 latency, tokens/sec, serving cost, build cost |
| Spot-preferred burst with on-demand fallback | interruption and scarcity are acceptable operating modes | spot-unavailable and interruption drills, capacity type, recovery time |

## Evidence Gate

A recommendation needs fields that match its claim:

- exact experiment, case, and serving profile
- completed, failed, dropped, interrupted, offered, and unserved work when
  applicable
- p95 and p99 latency
- request/sec and generated tokens/sec for load tests
- TTFT and inter-token timing for streaming tests
- peak waiting, running, and active requests for queue-sensitive questions
- GPU utilization and memory fields for GPU-efficiency claims
- cost fields for cost claims
- accuracy fields for quantization claims

When fields are missing, narrow the conclusion. A partial report can support
timeline or cost observations; it cannot support GPU efficiency, batching,
KV-cache, or target-optimization claims.
