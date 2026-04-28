# Experiment Platform Implementation Plan

## Goal

Evolve the lab from deployment validation into a repeatable ML-infra
experimentation platform. Each experiment should make one systems tradeoff
visible, use a controlled workload definition, and produce artifacts that can
be reviewed later without rerunning the cluster.

## Slice 1 - Experiment Catalog And Load Rendering

Status: implemented.

Purpose:

- define the repo structure for repeatable experiments
- document the full implementation roadmap
- add the first KV-cache experiment definition
- render a k6 Kubernetes load job from a checked-in experiment case
- keep the first slice local and testable without a live EKS cluster

Implementation:

- add `experiments/_templates/experiment.schema.yaml`
- add `experiments/kv-cache/experiment.yaml`
- add `experiments/kv-cache/cases.csv`
- add `experiments/kv-cache/README.md`
- add `experiments/kv-cache/results.md`
- add `scripts/experiment list|show|render-load`
- add shell tests for the new script surface and renderer

Acceptance criteria:

- `./scripts/experiment list` shows checked-in experiments
- `./scripts/experiment show kv-cache` prints the configured cases
- `./scripts/experiment render-load --experiment kv-cache --case prompt-512-output-100`
  writes a deterministic k6 Job manifest
- local shell tests cover the new command without requiring cluster access

## Slice 2 - Serving Profile Rendering

Status: implemented.

Purpose:

- let experiments vary vLLM settings without hand-editing
  `platform/inference/vllm-openai.yaml`
- support long-context runs such as the 8K KV-cache case
- preserve the existing default deployment for `verify` and `evaluate`

Implementation:

- add a render path for vLLM deployment variants
- make model name, served model name, max model length, GPU memory utilization,
  max sequences, and max batched tokens explicit inputs
- write rendered manifests to a temporary file or user-provided path
- add tests that verify only the intended vLLM arguments change
- add `experiments/kv-cache/serving-profiles.csv`
- add `./scripts/experiment render-serving`

Acceptance criteria:

- the default serving profile renders identically to the existing manifest
- the KV-cache profile can render `--max-model-len 8192`
- invalid model-length or scheduler values fail before `kubectl apply`

## Slice 3 - Metrics Contract And Report Schema

Status: implemented.

Purpose:

- make every experiment result comparable across runs
- separate raw Prometheus queries from curated experiment summaries

Implementation:

- define a JSON report schema for experiment runs
- capture workload shape, serving profile, timestamps, success counts, failures,
  p50/p95/p99 latency, TTFT, throughput, queue depth, GPU utilization, GPU
  memory, NodeClaim timing, pod readiness, and cost fields
- add an experiment report writer that can produce Markdown and JSON artifacts
  under `docs/reports/`
- add `experiments/_templates/report.schema.json`
- add `./scripts/experiment render-report`

Acceptance criteria:

- all experiment results include the same top-level metadata
- unavailable metrics are represented as `null` in JSON and `n/a` in Markdown
- reports distinguish workload configuration from measured results

## Slice 4 - KV Cache Vs Concurrency Runner

Status: implemented.

Purpose:

- prove how prompt length reduces stable concurrency through KV-cache pressure

Implementation:

- run prompt/output cases for 512/100, 2048/200, and 8192/300
- sweep concurrency or fixed arrival rate until the run saturates or fails
- record max stable concurrency, OOM events, request failures, memory pressure,
  throughput, and p95/p99 latency
- publish results in `experiments/kv-cache/results.md`
- add `./scripts/experiment run` for one case/profile at a time
- validate prompt plus output token budget against the selected serving
  profile's max model length before touching the cluster
- apply the rendered service, serving profile, and load case to a live cluster
- parse the k6 summary for completed requests, failed requests, request rate,
  and p50/p95/p99 latency
- detect visible vLLM `OOMKilled` termination reasons from pod status when
  Kubernetes still exposes them
- write Markdown/JSON reports and persist the k6 log next to the JSON report

Acceptance criteria:

- the 8K prompt case runs against a compatible max-model-length serving profile
- failed/OOM runs are reported as evidence, not hidden as script failures
- the result summary explains the concurrency drop in terms of KV-cache growth

Notes:

- The first runner implementation executes one case/profile at a time. The
  full concurrency sweep, Prometheus/DCGM GPU memory collection, and automatic
  `experiments/kv-cache/results.md` rollup remain follow-up work.

## Slice 5 - Prefill Vs Decode Timing

Status: planned.

Purpose:

- show where request time is spent for long-prompt/short-output versus
  short-prompt/long-output workloads

Implementation:

- add a streaming-capable client that records TTFT and inter-token latency
- run prefill-heavy and decode-heavy cases
- report TTFT, output tokens/sec, p95/p99 latency, and GPU utilization

Acceptance criteria:

- client-side TTFT is available even when Prometheus scrape timing is coarse
- results distinguish prefill pressure from decode pressure

## Slice 6 - Batching And Scheduler Tradeoffs

Status: planned.

Purpose:

- quantify throughput versus tail-latency tradeoffs under different scheduler
  limits

Implementation:

- compare constrained scheduling, limited batching, and vLLM default dynamic
  batching
- vary `--max-num-seqs` and `--max-num-batched-tokens`
- report tokens/sec, requests/sec, p50/p95/p99 latency, TTFT, and GPU
  utilization

Acceptance criteria:

- the report avoids claiming vLLM has a true no-batching mode
- every scheduler setting is captured in the report metadata

## Slice 7 - Request Pattern Utilization

Status: planned.

Purpose:

- explain why GPUs are often underutilized under real traffic shapes

Implementation:

- add steady, burst, uneven-size, and spike-to-zero workload profiles
- chart GPU utilization, queue depth, active requests, and tail latency over
  time

Acceptance criteria:

- the same serving profile can be compared across multiple traffic patterns
- the result summary ties utilization dips to request shape and scheduling

## Slice 8 - Autoscaling And Queueing Behavior

Status: planned.

Purpose:

- show that Karpenter/HPA scale-out is useful but not instant

Implementation:

- add overloaded burst and spike-to-zero experiments
- split scale-up into NodeClaim creation, node Ready, pod scheduled, container
  started, model Ready, and first successful completion
- compare direct client pressure with queued/backpressured behavior

Acceptance criteria:

- burst failures are attributed to provisioning delay, queue limits, or serving
  saturation
- reports can state how much buffering would have been required

## Slice 9 - Cost Per Useful Work

Status: planned.

Purpose:

- connect infrastructure decisions to dollars and useful output

Implementation:

- calculate cost per 1K successful requests
- calculate cost per 1M generated tokens
- compare naive constrained serving with concurrent/batched serving
- include SLO pass/fail beside cost metrics

Acceptance criteria:

- cost excludes non-serving infrastructure unless explicitly added
- failed requests are not counted as useful work

## Slice 10 - Failure Injection

Status: planned.

Purpose:

- prove recovery behavior under realistic serving failures

Implementation:

- add pod kill, GPU node deletion, OOM, slow inference, and timeout scenarios
- report request failure rate, retry behavior, time to recovery, and replacement
  capacity type

Acceptance criteria:

- failure injection is opt-in and clearly labeled
- cleanup restores NodePools and deployments after interrupted runs

## Slice 11 - Multi-Model Serving

Status: planned.

Purpose:

- expose resource contention and scheduling fairness when multiple model
  workloads share the platform

Implementation:

- add small-model and larger-model serving profiles
- compare isolated deployment, shared NodePool, and future same-GPU sharing
  options if MIG or fractional GPU support is introduced
- report fairness, latency impact, cold-start impact, and cost impact

Acceptance criteria:

- the report distinguishes Kubernetes scheduling contention from same-GPU
  runtime contention
- isolation recommendations are explicit

## Slice 12 - Graph Publishing And Summary Rollup

Status: planned.

Purpose:

- make experiment outcomes easy to scan in interviews and reviews

Implementation:

- generate charts from JSON reports
- store curated images under `experiments/*/graphs/`
- maintain `docs/experiments-summary.md` as the high-level narrative

Acceptance criteria:

- every completed experiment has a short result summary and at least one visual
- graphs are generated from checked-in JSON data, not hand-entered values
