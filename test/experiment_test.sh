#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

run_experiment_list_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" list

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment list should succeed"
  assert_contains "${COMMAND_OUTPUT}" "kv-cache" "experiment list should include the KV-cache experiment"
  assert_contains "${COMMAND_OUTPUT}" "KV Cache Vs Concurrency" "experiment list should include the KV-cache title"
  assert_contains "${COMMAND_OUTPUT}" "prefill-decode" "experiment list should include the prefill/decode experiment"
  assert_contains "${COMMAND_OUTPUT}" "Prefill Vs Decode Timing" "experiment list should include the prefill/decode title"
  assert_contains "${COMMAND_OUTPUT}" "batching" "experiment list should include the batching experiment"
  assert_contains "${COMMAND_OUTPUT}" "Batching Scheduler Tradeoffs" "experiment list should include the batching title"
  assert_contains "${COMMAND_OUTPUT}" "request-patterns" "experiment list should include the request-pattern experiment"
  assert_contains "${COMMAND_OUTPUT}" "Request Pattern Utilization" "experiment list should include the request-pattern title"
  assert_contains "${COMMAND_OUTPUT}" "autoscaling" "experiment list should include the autoscaling experiment"
  assert_contains "${COMMAND_OUTPUT}" "Autoscaling And Queueing Behavior" "experiment list should include the autoscaling title"
  assert_contains "${COMMAND_OUTPUT}" "cost" "experiment list should include the cost experiment"
  assert_contains "${COMMAND_OUTPUT}" "Cost Per Useful Work" "experiment list should include the cost title"
  assert_contains "${COMMAND_OUTPUT}" "fp4" "experiment list should include the FP4 experiment"
  assert_contains "${COMMAND_OUTPUT}" "FP4 Quantization Optimization" "experiment list should include the FP4 title"
}

run_experiment_validate_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" validate

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment validate should succeed for the checked-in catalog"
  assert_contains "${COMMAND_OUTPUT}" "Validated 7 experiment(s)." "validate should report the number of checked-in experiments"
}

run_experiment_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show kv-cache

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for kv-cache"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: kv-cache" "show output should include the experiment name"
  assert_contains "${COMMAND_OUTPUT}" "prompt-512-output-100" "show output should include the short prompt case"
  assert_contains "${COMMAND_OUTPUT}" "prompt=512 output=100" "show output should include case token settings"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300" "show output should include the long prompt case"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300-rate-010" "show output should include the long prompt stability sweep"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300-rate-115" "show output should include the narrowed long-context knee sweep"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300-rate-125-admission-032" "show output should include the admission-control comparison case"
  assert_contains "${COMMAND_OUTPUT}" "Client policies:" "show output should include KV-cache admission-control policy metadata"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300-rate-125-admission-032/admission-control" "show output should include the admission-control policy"
  assert_contains "${COMMAND_OUTPUT}" "Serving profiles:" "show output should include serving profiles"
  assert_contains "${COMMAND_OUTPUT}" "long-context" "show output should include the long-context serving profile"
  assert_contains "${COMMAND_OUTPUT}" "long-context-fp8-kv" "show output should include the FP8 KV cache profile"
  assert_contains "${COMMAND_OUTPUT}" "long-context-seqs-16" "show output should include conservative long-context scheduler variants"
  assert_contains "${COMMAND_OUTPUT}" "max_num_seqs=16 max_num_batched_tokens=9216" "show output should include scheduler settings for sequence-limit variants"
  assert_contains "${COMMAND_OUTPUT}" "Serving extensions:" "show output should include KV-cache serving extension metadata"
  assert_contains "${COMMAND_OUTPUT}" "long-context-fp8-kv: dtype=float16 tensor_parallel= node_profile= quantization= artifact= recipe_hash= kv_cache_dtype=fp8 calculate_kv_scales=true" "show output should include FP8 KV-cache settings"
}

run_prefill_decode_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show prefill-decode

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for prefill-decode"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: prefill-decode" "show output should include the prefill/decode experiment name"
  assert_contains "${COMMAND_OUTPUT}" "prefill-heavy" "show output should include the prefill-heavy case"
  assert_contains "${COMMAND_OUTPUT}" "decode-heavy" "show output should include the decode-heavy case"
  assert_contains "${COMMAND_OUTPUT}" "prompt=1536 output=64" "show output should include the prefill-heavy token settings"
  assert_contains "${COMMAND_OUTPUT}" "prompt=128 output=768" "show output should include the decode-heavy token settings"
}

run_batching_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show batching

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for batching"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: batching" "show output should include the batching experiment name"
  assert_contains "${COMMAND_OUTPUT}" "steady-512-output-128" "show output should include the steady batching case"
  assert_contains "${COMMAND_OUTPUT}" "burst-512-output-128" "show output should include the burst batching case"
  assert_contains "${COMMAND_OUTPUT}" "constrained-scheduler" "show output should include the constrained scheduler profile"
  assert_contains "${COMMAND_OUTPUT}" "limited-batching" "show output should include the limited batching profile"
  assert_contains "${COMMAND_OUTPUT}" "dynamic-default" "show output should include the dynamic default profile"
  assert_contains "${COMMAND_OUTPUT}" "max_num_seqs=1 max_num_batched_tokens=2048" "show output should include explicit constrained scheduler settings"
  assert_contains "${COMMAND_OUTPUT}" "scheduler=default" "show output should represent blank scheduler settings as defaults"
}

run_request_patterns_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show request-patterns

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for request-patterns"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: request-patterns" "show output should include the request-pattern experiment name"
  assert_contains "${COMMAND_OUTPUT}" "steady-small" "show output should include the steady traffic case"
  assert_contains "${COMMAND_OUTPUT}" "burst-small" "show output should include the burst traffic case"
  assert_contains "${COMMAND_OUTPUT}" "uneven-size-mix" "show output should include the uneven-size traffic case"
  assert_contains "${COMMAND_OUTPUT}" "spike-to-zero" "show output should include the spike-to-zero traffic case"
  assert_contains "${COMMAND_OUTPUT}" "Request shapes:" "show output should include mixed request shapes"
  assert_contains "${COMMAND_OUTPUT}" "uneven-size-mix/short: prompt=128 output=64 weight=6" "show output should include the short mixed request shape"
  assert_contains "${COMMAND_OUTPUT}" "uneven-size-mix/long: prompt=1536 output=512 weight=1" "show output should include the long mixed request shape"
  assert_contains "${COMMAND_OUTPUT}" "Serving profiles:" "show output should include the shared serving profile"
}

run_autoscaling_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show autoscaling

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for autoscaling"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: autoscaling" "show output should include the autoscaling experiment name"
  assert_contains "${COMMAND_OUTPUT}" "burst-direct" "show output should include the direct burst case"
  assert_contains "${COMMAND_OUTPUT}" "burst-queued" "show output should include the queued burst case"
  assert_contains "${COMMAND_OUTPUT}" "spike-direct" "show output should include the direct spike case"
  assert_contains "${COMMAND_OUTPUT}" "spike-queued" "show output should include the queued spike case"
  assert_contains "${COMMAND_OUTPUT}" "Client policies:" "show output should include client policies"
  assert_contains "${COMMAND_OUTPUT}" "burst-direct/direct: mode=direct executor=ramping-arrival-rate buffer_capacity=0 max_queue_wait=0s" "show output should include the direct client policy"
  assert_contains "${COMMAND_OUTPUT}" "burst-queued/bounded-queue: mode=queued executor=ramping-vus buffer_capacity=240 max_queue_wait=60s" "show output should include the queued client policy"
}

run_cost_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show cost

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for cost"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: cost" "show output should include the cost experiment name"
  assert_contains "${COMMAND_OUTPUT}" "steady-cost-efficiency" "show output should include the steady cost case"
  assert_contains "${COMMAND_OUTPUT}" "burst-cost-efficiency" "show output should include the burst cost case"
  assert_contains "${COMMAND_OUTPUT}" "Cost profiles:" "show output should include cost profiles"
  assert_contains "${COMMAND_OUTPUT}" "naive-single: hourly_cost=0.526 scope=serving-gpu-only p95_slo=2.0s p99_slo=5.0s" "show output should include the naive cost profile"
  assert_contains "${COMMAND_OUTPUT}" "optimized-batched: hourly_cost=0.526 scope=serving-gpu-only p95_slo=2.0s p99_slo=5.0s" "show output should include the optimized cost profile"
  assert_contains "${COMMAND_OUTPUT}" "max_num_seqs=32 max_num_batched_tokens=8192" "show output should include optimized scheduler settings"
}

run_fp4_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show fp4

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for fp4"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: fp4" "show output should include the FP4 experiment name"
  assert_contains "${COMMAND_OUTPUT}" "steady-512-output-128" "show output should include the steady FP4 case"
  assert_contains "${COMMAND_OUTPUT}" "bf16-baseline" "show output should include the BF16 serving profile"
  assert_contains "${COMMAND_OUTPUT}" "nvfp4-plain" "show output should include the plain NVFP4 serving profile"
  assert_contains "${COMMAND_OUTPUT}" "nvfp4-smoothquant" "show output should include the SmoothQuant NVFP4 serving profile"
  assert_contains "${COMMAND_OUTPUT}" "Cost details:" "show output should include cost details"
  assert_contains "${COMMAND_OUTPUT}" "instance=p6-b200.48xlarge region=us-west-2" "show output should include the Blackwell cost input"
  assert_contains "${COMMAND_OUTPUT}" "Accuracy cases:" "show output should include accuracy cases"
  assert_contains "${COMMAND_OUTPUT}" "tasks=arc_easy,hellaswag,winogrande fewshot=0 limit=200" "show output should include fixed accuracy tasks"
  assert_contains "${COMMAND_OUTPUT}" "Quantization jobs:" "show output should include quantization jobs"
  assert_contains "${COMMAND_OUTPUT}" "recipe=quantization/smoothquant_nvfp4_recipe.py" "show output should include the SmoothQuant recipe"
  assert_contains "${COMMAND_OUTPUT}" "Serving extensions:" "show output should include serving extensions"
  assert_contains "${COMMAND_OUTPUT}" "dtype=auto tensor_parallel=8 node_profile=blackwell quantization=nvfp4+smoothquant" "show output should include Blackwell serving metadata"
}

run_render_load_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case prompt-512-output-100 \
    --output "${TEST_TMPDIR}/kv-cache-load.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should render the selected case"
  assert_contains "${COMMAND_OUTPUT}" "Rendered load manifest: ${TEST_TMPDIR}/kv-cache-load.yaml" "render-load should print the output path"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-load.yaml" "render-load should write the manifest"

  RENDERED_MANIFEST=$(cat "${TEST_TMPDIR}/kv-cache-load.yaml")

  assert_contains "${RENDERED_MANIFEST}" "name: kv-cache-prompt-512-output-100-load" "rendered manifest should name the ConfigMap from the experiment and case"
  assert_contains "${RENDERED_MANIFEST}" "name: kv-cache-prompt-512-output-100" "rendered manifest should name the Job from the experiment and case"
  assert_contains "${RENDERED_MANIFEST}" "const promptTokenTarget = 512;" "rendered manifest should include the prompt token target"
  assert_contains "${RENDERED_MANIFEST}" "const maxTokens = 100;" "rendered manifest should include the output token cap"
  assert_contains "${RENDERED_MANIFEST}" 'const clientPolicy = "direct";' "rendered manifest should default to the direct client policy"
  assert_contains "${RENDERED_MANIFEST}" 'executor: "ramping-arrival-rate"' "rendered manifest should default to open-loop arrival rate"
  assert_contains "${RENDERED_MANIFEST}" 'import { Counter } from "k6/metrics";' "rendered manifest should include a token counter"
  assert_contains "${RENDERED_MANIFEST}" 'const completionTokens = new Counter("completion_tokens");' "rendered manifest should track completion tokens"
  assert_contains "${RENDERED_MANIFEST}" "GPU_LAB_K6_SUMMARY_BEGIN" "rendered manifest should emit a parseable k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "p99_request_latency_seconds=" "rendered manifest should include p99 latency in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "dropped_iterations=" "rendered manifest should include dropped iterations in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "interrupted_iterations=" "rendered manifest should include interrupted iterations in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "const bufferingRequiredRequests = String(Number(droppedIterations) + Number(interruptedIterations));" "rendered manifest should count dropped and interrupted iterations as buffering pressure"
  assert_contains "${RENDERED_MANIFEST}" "buffering_required_requests=" "rendered manifest should include buffering required in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "generated_tokens=" "rendered manifest should include generated token counts in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "generation_tokens_per_second=" "rendered manifest should include generated token throughput in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "run_duration_seconds=" "rendered manifest should include run duration in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "summaryTrendStats" "rendered manifest should request p95 and p99 k6 summaries"
  assert_contains "${RENDERED_MANIFEST}" "value: http://vllm-openai.app.svc.cluster.local/v1/completions" "rendered manifest should target the in-cluster vLLM service"

  teardown_test_tmpdir
}

run_render_fractional_arrival_rate_load_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case prompt-8192-output-300-rate-010 \
    --output "${TEST_TMPDIR}/kv-cache-rate-010.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should support fractional arrival-rate cases"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-rate-010.yaml" "render-load should write the fractional-rate manifest"

  FRACTIONAL_MANIFEST=$(cat "${TEST_TMPDIR}/kv-cache-rate-010.yaml")

  assert_contains "${FRACTIONAL_MANIFEST}" 'executor: "ramping-arrival-rate"' "fractional-rate load should still use arrival-rate execution"
  assert_contains "${FRACTIONAL_MANIFEST}" "startRate: 0" "fractional-rate load should render an integer start rate for k6"
  assert_contains "${FRACTIONAL_MANIFEST}" 'timeUnit: "10s"' "fractional-rate load should render a longer timeUnit instead of decimal targets"
  assert_contains "${FRACTIONAL_MANIFEST}" '{ duration: "2m", target: 1 }' "fractional-rate load should render an integer target for k6"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case prompt-8192-output-300-rate-125 \
    --output "${TEST_TMPDIR}/kv-cache-rate-125.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should support fractional arrival rates above one request per second"
  RATE_125_MANIFEST=$(cat "${TEST_TMPDIR}/kv-cache-rate-125.yaml")

  assert_contains "${RATE_125_MANIFEST}" 'timeUnit: "4s"' "fractional-rate load should use the smallest exact integer time unit"
  assert_contains "${RATE_125_MANIFEST}" '{ duration: "2m", target: 5 }' "fractional-rate load should render 1.25 req/s as five arrivals per four seconds"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case prompt-8192-output-300-rate-105 \
    --output "${TEST_TMPDIR}/kv-cache-rate-105.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should support narrowed fractional knee probes"
  RATE_105_MANIFEST=$(cat "${TEST_TMPDIR}/kv-cache-rate-105.yaml")

  assert_contains "${RATE_105_MANIFEST}" 'timeUnit: "20s"' "fractional-rate load should render 1.05 req/s as a precise 20-second window"
  assert_contains "${RATE_105_MANIFEST}" '{ duration: "2m", target: 21 }' "fractional-rate load should render 1.05 req/s as twenty-one arrivals per twenty seconds"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case prompt-8192-output-300-rate-125-admission-032 \
    --output "${TEST_TMPDIR}/kv-cache-admission.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should render the admission-control comparison case"
  ADMISSION_MANIFEST=$(cat "${TEST_TMPDIR}/kv-cache-admission.yaml")

  assert_contains "${ADMISSION_MANIFEST}" 'const clientPolicy = "admission-control";' "admission-control load should include policy metadata"
  assert_contains "${ADMISSION_MANIFEST}" "preAllocatedVUs: 32" "admission-control load should cap preallocated VUs at the serving sequence limit"
  assert_contains "${ADMISSION_MANIFEST}" "maxVUs: 32" "admission-control load should cap max VUs at the serving sequence limit"

  teardown_test_tmpdir
}

run_render_autoscaling_load_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment autoscaling \
    --case burst-queued \
    --output "${TEST_TMPDIR}/autoscaling-burst-queued.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should render the queued autoscaling case"
  assert_file_exists "${TEST_TMPDIR}/autoscaling-burst-queued.yaml" "render-load should write the queued autoscaling manifest"

  AUTOSCALING_MANIFEST=$(cat "${TEST_TMPDIR}/autoscaling-burst-queued.yaml")

  assert_contains "${AUTOSCALING_MANIFEST}" 'const clientPolicy = "bounded-queue";' "queued load manifest should include the bounded queue policy"
  assert_contains "${AUTOSCALING_MANIFEST}" 'const clientMode = "queued";' "queued load manifest should include the queued client mode"
  assert_contains "${AUTOSCALING_MANIFEST}" "const bufferCapacityRequests = 240;" "queued load manifest should include buffer capacity metadata"
  assert_contains "${AUTOSCALING_MANIFEST}" "const maxQueueWaitSeconds = 60;" "queued load manifest should include max queue wait metadata"
  assert_contains "${AUTOSCALING_MANIFEST}" "client_policy: clientPolicy" "queued load manifest should tag the client policy"
  assert_contains "${AUTOSCALING_MANIFEST}" 'executor: "ramping-vus"' "queued load manifest should use the closed-loop ramping-vus executor"
  assert_contains "${AUTOSCALING_MANIFEST}" "startVUs: 1" "queued load manifest should render start VUs from the case"
  assert_contains "${AUTOSCALING_MANIFEST}" '{ duration: "15s", target: 24 }' "queued load manifest should render target VUs from the case"

  teardown_test_tmpdir
}

run_render_request_pattern_load_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment request-patterns \
    --case uneven-size-mix \
    --output "${TEST_TMPDIR}/request-patterns-uneven.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-load should render the uneven request-pattern case"
  assert_file_exists "${TEST_TMPDIR}/request-patterns-uneven.yaml" "render-load should write the uneven request-pattern manifest"

  REQUEST_PATTERN_MANIFEST=$(cat "${TEST_TMPDIR}/request-patterns-uneven.yaml")

  assert_contains "${REQUEST_PATTERN_MANIFEST}" 'const requestShapes = [{ label: "short", promptTokenTarget: 128, maxTokens: 64, weight: 6 }, { label: "medium", promptTokenTarget: 512, maxTokens: 128, weight: 3 }, { label: "long", promptTokenTarget: 1536, maxTokens: 512, weight: 1 }];' "uneven load manifest should embed weighted request shapes"
  assert_contains "${REQUEST_PATTERN_MANIFEST}" "function selectRequestShape()" "uneven load manifest should select a shape per request"
  assert_contains "${REQUEST_PATTERN_MANIFEST}" "prompt: buildPrompt(requestShape.promptTokenTarget)" "uneven load manifest should build prompts from selected shapes"
  assert_contains "${REQUEST_PATTERN_MANIFEST}" "max_tokens: requestShape.maxTokens" "uneven load manifest should set output caps from selected shapes"
  assert_contains "${REQUEST_PATTERN_MANIFEST}" "request_shape: requestShape.label" "uneven load manifest should tag requests by selected shape"

  teardown_test_tmpdir
}

run_render_stream_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-stream \
    --experiment prefill-decode \
    --case prefill-heavy \
    --samples 3 \
    --concurrency 2 \
    --output "${TEST_TMPDIR}/prefill-stream.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-stream should render the selected streaming case"
  assert_contains "${COMMAND_OUTPUT}" "Rendered stream manifest: ${TEST_TMPDIR}/prefill-stream.yaml" "render-stream should print the output path"
  assert_file_exists "${TEST_TMPDIR}/prefill-stream.yaml" "render-stream should write the manifest"

  STREAM_MANIFEST=$(cat "${TEST_TMPDIR}/prefill-stream.yaml")

  assert_contains "${STREAM_MANIFEST}" "name: prefill-decode-prefill-heavy-stream-client" "stream manifest should name the ConfigMap from the experiment and case"
  assert_contains "${STREAM_MANIFEST}" "name: prefill-decode-prefill-heavy-stream" "stream manifest should name the Job from the experiment and case"
  assert_contains "${STREAM_MANIFEST}" "samples = 3" "stream manifest should include the requested sample count"
  assert_contains "${STREAM_MANIFEST}" "stream_concurrency = 2" "stream manifest should include the requested concurrency"
  assert_contains "${STREAM_MANIFEST}" 'request_shapes = [{"id":"prefill-heavy","prompt_token_target":1536,"max_tokens":64,"weight":1}]' "stream manifest should include the fallback request shape"
  assert_contains "${STREAM_MANIFEST}" "ThreadPoolExecutor(max_workers=stream_concurrency)" "stream manifest should run samples concurrently when requested"
  assert_contains "${STREAM_MANIFEST}" "def select_request_shape():" "stream manifest should select a request shape per sample"
  assert_contains "${STREAM_MANIFEST}" "stream_shape_summaries=" "stream manifest should emit per-shape summary JSON"
  assert_contains "${STREAM_MANIFEST}" "stream_shape_summary_row=" "stream manifest should emit per-shape Markdown rows"
  assert_contains "${STREAM_MANIFEST}" '"stream": True' "stream manifest should request streamed completions"
  assert_contains "${STREAM_MANIFEST}" "GPU_LAB_STREAM_SUMMARY_BEGIN" "stream manifest should emit a parseable streaming summary"
  assert_contains "${STREAM_MANIFEST}" "p95_ttft_seconds=" "stream manifest should include TTFT in the summary"
  assert_contains "${STREAM_MANIFEST}" "p95_inter_token_latency_seconds=" "stream manifest should include inter-token latency in the summary"
  assert_contains "${STREAM_MANIFEST}" "image: python:3.12-slim" "stream manifest should use a standard Python client image"

  teardown_test_tmpdir
}

run_render_mixed_stream_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-stream \
    --experiment prefill-decode \
    --case mixed-prefill-decode \
    --samples 4 \
    --concurrency 2 \
    --output "${TEST_TMPDIR}/mixed-stream.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-stream should render the mixed prefill/decode case"
  assert_file_exists "${TEST_TMPDIR}/mixed-stream.yaml" "render-stream should write the mixed manifest"

  MIXED_STREAM_MANIFEST=$(cat "${TEST_TMPDIR}/mixed-stream.yaml")

  assert_contains "${MIXED_STREAM_MANIFEST}" "name: prefill-decode-mixed-prefill-decode-stream-client" "mixed stream manifest should name the ConfigMap from the experiment and case"
  assert_contains "${MIXED_STREAM_MANIFEST}" 'request_shapes = [{"id":"prefill-heavy","prompt_token_target":1536,"max_tokens":64,"weight":1}, {"id":"decode-heavy","prompt_token_target":128,"max_tokens":768,"weight":1}]' "mixed stream manifest should embed weighted prefill/decode shapes"
  assert_contains "${MIXED_STREAM_MANIFEST}" 'future_shapes[executor.submit(stream_once, request_shape)] = request_shape' "mixed stream manifest should track the selected shape for each sample"
  assert_contains "${MIXED_STREAM_MANIFEST}" '"prompt": build_prompt(request_shape["prompt_token_target"])' "mixed stream manifest should build prompts from the selected shape"
  assert_contains "${MIXED_STREAM_MANIFEST}" '"max_tokens": request_shape["max_tokens"]' "mixed stream manifest should set output caps from the selected shape"

  teardown_test_tmpdir
}

run_render_fp4_quantization_manifest_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-quantization \
    --experiment fp4 \
    --profile nvfp4-smoothquant \
    --output "${TEST_TMPDIR}/fp4-smoothquant-quantize.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-quantization should render the SmoothQuant NVFP4 job"
  assert_contains "${COMMAND_OUTPUT}" "Rendered quantization manifest: ${TEST_TMPDIR}/fp4-smoothquant-quantize.yaml" "render-quantization should print the output path"
  assert_file_exists "${TEST_TMPDIR}/fp4-smoothquant-quantize.yaml" "render-quantization should write the manifest"

  QUANTIZATION_MANIFEST=$(cat "${TEST_TMPDIR}/fp4-smoothquant-quantize.yaml")

  assert_contains "${QUANTIZATION_MANIFEST}" "name: fp4-nvfp4-smoothquant-quantize" "quantization manifest should name the job from the profile"
  assert_contains "${QUANTIZATION_MANIFEST}" "SmoothQuantModifier" "quantization manifest should include the SmoothQuant recipe"
  assert_contains "${QUANTIZATION_MANIFEST}" "smoothing_strength=0.5" "quantization manifest should include the SmoothQuant strength"
  assert_contains "${QUANTIZATION_MANIFEST}" "QuantizationModifier" "quantization manifest should include the NVFP4 modifier"
  assert_contains "${QUANTIZATION_MANIFEST}" "scheme=\"NVFP4\"" "quantization manifest should include the NVFP4 scheme"
  assert_contains "${QUANTIZATION_MANIFEST}" "value: Qwen/Qwen2.5-7B-Instruct" "quantization manifest should use the BF16 base model"
  assert_contains "${QUANTIZATION_MANIFEST}" "value: /models/qwen25-7b-nvfp4-smoothquant" "quantization manifest should write the optimized artifact path"
  assert_contains "${QUANTIZATION_MANIFEST}" "value: HuggingFaceH4/ultrachat_200k" "quantization manifest should use the shared calibration dataset"
  assert_contains "${QUANTIZATION_MANIFEST}" "value: \"512\"" "quantization manifest should use the shared calibration sample count"
  assert_contains "${QUANTIZATION_MANIFEST}" "node.kubernetes.io/instance-type: p6-b200.48xlarge" "quantization manifest should target p6-b200 capacity"
  assert_contains "${QUANTIZATION_MANIFEST}" "nvidia.com/gpu: \"8\"" "quantization manifest should request a full 8 GPU instance"
  assert_contains "${QUANTIZATION_MANIFEST}" "claimName: model-artifacts" "quantization manifest should persist artifacts outside the job pod"

  teardown_test_tmpdir
}

run_render_fp4_accuracy_manifest_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-accuracy \
    --experiment fp4 \
    --profile bf16-baseline \
    --output "${TEST_TMPDIR}/fp4-accuracy.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-accuracy should render the FP4 accuracy job"
  assert_contains "${COMMAND_OUTPUT}" "Rendered accuracy manifest: ${TEST_TMPDIR}/fp4-accuracy.yaml" "render-accuracy should print the output path"
  assert_file_exists "${TEST_TMPDIR}/fp4-accuracy.yaml" "render-accuracy should write the manifest"

  ACCURACY_MANIFEST=$(cat "${TEST_TMPDIR}/fp4-accuracy.yaml")

  assert_contains "${ACCURACY_MANIFEST}" "name: fp4-bf16-baseline-fp4-quality-0shot-accuracy" "accuracy manifest should name the job from the profile and accuracy case"
  assert_contains "${ACCURACY_MANIFEST}" "ghcr.io/eleutherai/lm-evaluation-harness:latest" "accuracy manifest should use an lm-eval image"
  assert_contains "${ACCURACY_MANIFEST}" 'tasks = "arc_easy,hellaswag,winogrande"' "accuracy manifest should include the requested tasks"
  assert_contains "${ACCURACY_MANIFEST}" 'num_fewshot = "0"' "accuracy manifest should be zero-shot"
  assert_contains "${ACCURACY_MANIFEST}" 'limit = "200"' "accuracy manifest should use the requested limit"
  assert_contains "${ACCURACY_MANIFEST}" 'model_name = "qwen2.5-7b-bf16"' "accuracy manifest should use the served model name"
  assert_contains "${ACCURACY_MANIFEST}" "GPU_LAB_ACCURACY_SUMMARY_BEGIN" "accuracy manifest should emit parseable summary markers"

  teardown_test_tmpdir
}

run_render_unknown_case_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-load \
    --experiment kv-cache \
    --case missing-case

  assert_status 1 "${COMMAND_STATUS}" "render-load should fail for an unknown case"
  assert_contains "${COMMAND_OUTPUT}" "Unknown case missing-case for experiment kv-cache" "render-load should explain the unknown case"
}

run_render_default_serving_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment kv-cache \
    --profile default \
    --output "${TEST_TMPDIR}/vllm-default.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the default serving profile"
  assert_contains "${COMMAND_OUTPUT}" "Rendered serving manifest: ${TEST_TMPDIR}/vllm-default.yaml" "render-serving should print the output path"
  assert_file_exists "${TEST_TMPDIR}/vllm-default.yaml" "render-serving should write the serving manifest"

  DEFAULT_DIFF=$(diff -u "${REPO_ROOT}/platform/inference/vllm-openai.yaml" "${TEST_TMPDIR}/vllm-default.yaml" || true)
  assert_eq "" "${DEFAULT_DIFF}" "the default serving profile should render identically to the checked-in vLLM manifest"

  teardown_test_tmpdir
}

run_render_long_context_serving_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment kv-cache \
    --profile long-context \
    --output "${TEST_TMPDIR}/vllm-long-context.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the long-context serving profile"
  assert_file_exists "${TEST_TMPDIR}/vllm-long-context.yaml" "render-serving should write the long-context manifest"

  SERVING_MANIFEST=$(cat "${TEST_TMPDIR}/vllm-long-context.yaml")

  assert_contains "${SERVING_MANIFEST}" '- --max-model-len' "long-context manifest should include the max model length argument"
  assert_contains "${SERVING_MANIFEST}" '- "9216"' "long-context manifest should raise max model length to 9216"
  assert_contains "${SERVING_MANIFEST}" '- --gpu-memory-utilization' "long-context manifest should include GPU memory utilization"
  assert_contains "${SERVING_MANIFEST}" '- "0.90"' "long-context manifest should raise GPU memory utilization"
  assert_contains "${SERVING_MANIFEST}" '- --max-num-seqs' "long-context manifest should include an explicit max sequence limit"
  assert_contains "${SERVING_MANIFEST}" '- "32"' "long-context manifest should include the max sequence value"
  assert_contains "${SERVING_MANIFEST}" '- --max-num-batched-tokens' "long-context manifest should include a batched-token limit"
  assert_contains "${SERVING_MANIFEST}" '- "9216"' "long-context manifest should include the batched-token value"
  assert_not_contains "${SERVING_MANIFEST}" '--kv-cache-dtype' "baseline long-context manifest should not set KV cache dtype"
  assert_not_contains "${SERVING_MANIFEST}" '--calculate-kv-scales' "baseline long-context manifest should not calculate KV scales"

  teardown_test_tmpdir
}

run_render_fp8_kv_serving_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment kv-cache \
    --profile long-context-fp8-kv \
    --output "${TEST_TMPDIR}/vllm-long-context-fp8-kv.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the FP8 KV cache profile"
  assert_file_exists "${TEST_TMPDIR}/vllm-long-context-fp8-kv.yaml" "render-serving should write the FP8 KV manifest"

  FP8_KV_MANIFEST=$(cat "${TEST_TMPDIR}/vllm-long-context-fp8-kv.yaml")

  assert_contains "${FP8_KV_MANIFEST}" '- --max-model-len' "FP8 KV manifest should keep the long-context model length"
  assert_contains "${FP8_KV_MANIFEST}" '- "9216"' "FP8 KV manifest should keep the long-context length and token budget"
  assert_contains "${FP8_KV_MANIFEST}" '- --max-num-seqs' "FP8 KV manifest should keep the long-context sequence limit"
  assert_contains "${FP8_KV_MANIFEST}" '- "32"' "FP8 KV manifest should keep the long-context sequence value"
  assert_contains "${FP8_KV_MANIFEST}" '- --max-num-batched-tokens' "FP8 KV manifest should keep the long-context batched-token limit"
  assert_contains "${FP8_KV_MANIFEST}" '- --kv-cache-dtype' "FP8 KV manifest should set KV cache dtype"
  assert_contains "${FP8_KV_MANIFEST}" '- fp8' "FP8 KV manifest should use fp8 KV storage"
  assert_contains "${FP8_KV_MANIFEST}" '- --calculate-kv-scales' "FP8 KV manifest should calculate KV scales dynamically"
  assert_contains "${FP8_KV_MANIFEST}" 'nvidia.com/gpu: "1"' "FP8 KV manifest should keep the existing one-GPU serving shape"
  assert_not_contains "${FP8_KV_MANIFEST}" 'node.kubernetes.io/instance-type: p6-b200.48xlarge' "FP8 KV manifest should not select B200 capacity"

  teardown_test_tmpdir
}

run_render_batching_serving_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment batching \
    --profile constrained-scheduler \
    --output "${TEST_TMPDIR}/vllm-batching-constrained.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the constrained batching profile"
  assert_file_exists "${TEST_TMPDIR}/vllm-batching-constrained.yaml" "render-serving should write the constrained batching manifest"

  CONSTRAINED_MANIFEST=$(cat "${TEST_TMPDIR}/vllm-batching-constrained.yaml")

  assert_contains "${CONSTRAINED_MANIFEST}" '- --max-num-seqs' "constrained batching manifest should include max sequence limit"
  assert_contains "${CONSTRAINED_MANIFEST}" '- "1"' "constrained batching manifest should include the max sequence value"
  assert_contains "${CONSTRAINED_MANIFEST}" '- --max-num-batched-tokens' "constrained batching manifest should include max batched tokens"
  assert_contains "${CONSTRAINED_MANIFEST}" '- "2048"' "constrained batching manifest should include the batched-token value"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment batching \
    --profile dynamic-default \
    --output "${TEST_TMPDIR}/vllm-batching-dynamic-default.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the dynamic default batching profile"
  assert_file_exists "${TEST_TMPDIR}/vllm-batching-dynamic-default.yaml" "render-serving should write the dynamic default manifest"

  DYNAMIC_MANIFEST=$(cat "${TEST_TMPDIR}/vllm-batching-dynamic-default.yaml")

  assert_not_contains "${DYNAMIC_MANIFEST}" '--max-num-seqs' "dynamic default manifest should not set an explicit max sequence limit"
  assert_not_contains "${DYNAMIC_MANIFEST}" '--max-num-batched-tokens' "dynamic default manifest should not set an explicit batched-token limit"
  assert_contains "${DYNAMIC_MANIFEST}" '- --max-model-len' "dynamic default manifest should still include the max model length"
  assert_contains "${DYNAMIC_MANIFEST}" '- "2048"' "dynamic default manifest should keep the 2048 model length"

  teardown_test_tmpdir
}

run_render_fp4_serving_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment fp4 \
    --profile nvfp4-smoothquant \
    --output "${TEST_TMPDIR}/vllm-fp4-smoothquant.yaml"

  assert_status 0 "${COMMAND_STATUS}" "render-serving should render the FP4 SmoothQuant profile"
  assert_file_exists "${TEST_TMPDIR}/vllm-fp4-smoothquant.yaml" "render-serving should write the FP4 serving manifest"

  FP4_SERVING_MANIFEST=$(cat "${TEST_TMPDIR}/vllm-fp4-smoothquant.yaml")

  assert_contains "${FP4_SERVING_MANIFEST}" "image: vllm/vllm-openai:v0.20.1" "FP4 serving should use the requested vLLM image"
  assert_contains "${FP4_SERVING_MANIFEST}" "- /models/qwen25-7b-nvfp4-smoothquant" "FP4 serving should target the quantized artifact path"
  assert_contains "${FP4_SERVING_MANIFEST}" "- --dtype" "FP4 serving should render dtype explicitly"
  assert_contains "${FP4_SERVING_MANIFEST}" "- auto" "FP4 serving should use dtype auto"
  assert_contains "${FP4_SERVING_MANIFEST}" "- --tensor-parallel-size" "FP4 serving should request tensor parallelism"
  assert_contains "${FP4_SERVING_MANIFEST}" "- \"8\"" "FP4 serving should use all 8 B200 GPUs"
  assert_contains "${FP4_SERVING_MANIFEST}" "node.kubernetes.io/instance-type: p6-b200.48xlarge" "FP4 serving should target p6-b200 capacity"
  assert_contains "${FP4_SERVING_MANIFEST}" "nvidia.com/gpu: \"8\"" "FP4 serving should request the full 8 GPU instance"
  assert_contains "${FP4_SERVING_MANIFEST}" "mountPath: /models" "FP4 serving should mount local model artifacts"
  assert_contains "${FP4_SERVING_MANIFEST}" "claimName: model-artifacts" "FP4 serving should read quantized artifacts from the shared PVC"

  teardown_test_tmpdir
}

run_render_unknown_serving_profile_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-serving \
    --experiment kv-cache \
    --profile missing-profile

  assert_status 1 "${COMMAND_STATUS}" "render-serving should fail for an unknown serving profile"
  assert_contains "${COMMAND_OUTPUT}" "Unknown serving profile missing-profile for experiment kv-cache" "render-serving should explain the unknown serving profile"
}

run_render_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment kv-cache \
    --case prompt-8192-output-300 \
    --profile long-context \
    --report "${TEST_TMPDIR}/kv-cache-report.md" \
    --json-report "${TEST_TMPDIR}/kv-cache-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should write report scaffold artifacts"
  assert_contains "${COMMAND_OUTPUT}" "Rendered Markdown report: ${TEST_TMPDIR}/kv-cache-report.md" "render-report should print the Markdown report path"
  assert_contains "${COMMAND_OUTPUT}" "Rendered JSON report: ${TEST_TMPDIR}/kv-cache-report.json" "render-report should print the JSON report path"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-report.md" "render-report should write the Markdown report"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-report.json" "render-report should write the JSON report"

  REPORT_CONTENT=$(cat "${TEST_TMPDIR}/kv-cache-report.md")
  JSON_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/kv-cache-report.json")

  assert_contains "${REPORT_CONTENT}" "Schema version: experiment-report/v1" "Markdown report should include the schema version"
  assert_contains "${REPORT_CONTENT}" "Requires live cluster: true" "Markdown report should state that measured results require a live cluster"
  assert_contains "${REPORT_CONTENT}" "| Prompt token target | 8192 |" "Markdown report should include workload metadata"
  assert_contains "${REPORT_CONTENT}" "| Max model length | 9216 |" "Markdown report should include serving metadata"
  assert_contains "${REPORT_CONTENT}" "| KV cache dtype | n/a |" "Markdown report should include blank KV cache dtype metadata"
  assert_contains "${REPORT_CONTENT}" "| Calculate KV scales | n/a |" "Markdown report should include blank KV scale metadata"
  assert_contains "${REPORT_CONTENT}" "| p99 request latency | n/a |" "Markdown report should render unavailable metrics as n/a"
  assert_contains "${REPORT_CONTENT}" "| GPU memory used | n/a |" "Markdown report should render unavailable GPU memory metrics as n/a"
  assert_contains "${REPORT_CONTENT}" "Unavailable fields remain \`n/a\` when the runner did not collect that signal" "Markdown report should explain unavailable metrics conservatively"
  assert_contains "${JSON_REPORT_CONTENT}" "\"schema_version\": \"experiment-report/v1\"" "JSON report should include the schema version"
  assert_contains "${JSON_REPORT_CONTENT}" "\"status\": \"pending\"" "JSON report should mark the scaffold as pending"
  assert_contains "${JSON_REPORT_CONTENT}" "\"requires_live_cluster\": true" "JSON report should state that measured results require a live cluster"
  assert_contains "${JSON_REPORT_CONTENT}" "\"prompt_token_target\": 8192" "JSON report should include workload metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"max_model_len\": 9216" "JSON report should include serving metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"kv_cache_dtype\": null" "JSON report should include blank KV cache dtype metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"calculate_kv_scales\": null" "JSON report should include blank KV scale metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"max_num_seqs\": 32" "JSON report should include scheduler metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"max_num_batched_tokens\": 9216" "JSON report should include batched-token metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p99_request_latency_seconds\": null" "JSON report should render unavailable latency as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p50_ttft_seconds\": null" "JSON report should render unavailable TTFT as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p95_inter_token_latency_seconds\": null" "JSON report should render unavailable inter-token latency as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"gpu_memory_used_bytes\": null" "JSON report should render unavailable GPU memory as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"cost_per_1000_successful_requests_usd\": null" "JSON report should render unavailable cost as null"

  teardown_test_tmpdir
}

run_render_fp8_kv_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment kv-cache \
    --case prompt-8192-output-300-rate-125 \
    --profile long-context-fp8-kv \
    --report "${TEST_TMPDIR}/kv-cache-fp8-kv-report.md" \
    --json-report "${TEST_TMPDIR}/kv-cache-fp8-kv-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should write FP8 KV report scaffold artifacts"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-fp8-kv-report.md" "render-report should write the FP8 KV Markdown report"
  assert_file_exists "${TEST_TMPDIR}/kv-cache-fp8-kv-report.json" "render-report should write the FP8 KV JSON report"

  FP8_KV_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/kv-cache-fp8-kv-report.md")
  FP8_KV_JSON_CONTENT=$(cat "${TEST_TMPDIR}/kv-cache-fp8-kv-report.json")

  assert_contains "${FP8_KV_REPORT_CONTENT}" "| Profile | long-context-fp8-kv |" "FP8 KV report should include the selected profile"
  assert_contains "${FP8_KV_REPORT_CONTENT}" "| KV cache dtype | fp8 |" "FP8 KV report should include KV cache dtype"
  assert_contains "${FP8_KV_REPORT_CONTENT}" "| Calculate KV scales | true |" "FP8 KV report should include dynamic scale metadata"
  assert_contains "${FP8_KV_REPORT_CONTENT}" "| Max sequences | 32 |" "FP8 KV report should keep long-context sequence metadata"
  assert_contains "${FP8_KV_JSON_CONTENT}" "\"id\": \"long-context-fp8-kv\"" "FP8 KV JSON report should include the profile id"
  assert_contains "${FP8_KV_JSON_CONTENT}" "\"kv_cache_dtype\": \"fp8\"" "FP8 KV JSON report should include KV cache dtype"
  assert_contains "${FP8_KV_JSON_CONTENT}" "\"calculate_kv_scales\": true" "FP8 KV JSON report should include dynamic scale metadata"
  assert_contains "${FP8_KV_JSON_CONTENT}" "\"max_num_seqs\": 32" "FP8 KV JSON report should keep long-context sequence metadata"

  teardown_test_tmpdir
}

run_render_report_incompatible_profile_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment kv-cache \
    --case prompt-8192-output-300 \
    --profile default \
    --report "${TEST_TMPDIR}/bad-report.md" \
    --json-report "${TEST_TMPDIR}/bad-report.json"

  assert_status 1 "${COMMAND_STATUS}" "render-report should reject incompatible context/profile combinations"
  assert_contains "${COMMAND_OUTPUT}" "max_model_len 2048 is smaller than case prompt-8192-output-300 prompt+output budget 8492" "render-report should explain incompatible max model length"
  assert_file_not_exists "${TEST_TMPDIR}/bad-report.md" "incompatible render-report should not write Markdown"
  assert_file_not_exists "${TEST_TMPDIR}/bad-report.json" "incompatible render-report should not write JSON"

  teardown_test_tmpdir
}

run_render_batching_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment batching \
    --case steady-512-output-128 \
    --profile dynamic-default \
    --report "${TEST_TMPDIR}/batching-report.md" \
    --json-report "${TEST_TMPDIR}/batching-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should render the batching report scaffold"
  assert_file_exists "${TEST_TMPDIR}/batching-report.md" "render-report should write the batching Markdown report"
  assert_file_exists "${TEST_TMPDIR}/batching-report.json" "render-report should write the batching JSON report"

  BATCHING_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/batching-report.md")
  BATCHING_JSON_CONTENT=$(cat "${TEST_TMPDIR}/batching-report.json")

  assert_contains "${BATCHING_REPORT_CONTENT}" "# Batching Scheduler Tradeoffs - steady-512-output-128" "batching report should include the experiment title and case"
  assert_contains "${BATCHING_REPORT_CONTENT}" "| Profile | dynamic-default |" "batching report should include the selected profile"
  assert_contains "${BATCHING_REPORT_CONTENT}" "| Max sequences | n/a |" "dynamic default report should render max sequences as n/a"
  assert_contains "${BATCHING_REPORT_CONTENT}" "| Max batched tokens | n/a |" "dynamic default report should render max batched tokens as n/a"
  assert_contains "${BATCHING_JSON_CONTENT}" "\"name\": \"batching\"" "batching JSON report should include the experiment name"
  assert_contains "${BATCHING_JSON_CONTENT}" "\"id\": \"dynamic-default\"" "batching JSON report should include the profile id"
  assert_contains "${BATCHING_JSON_CONTENT}" "\"max_num_seqs\": null" "dynamic default report should persist null max sequence metadata"
  assert_contains "${BATCHING_JSON_CONTENT}" "\"max_num_batched_tokens\": null" "dynamic default report should persist null batched-token metadata"

  teardown_test_tmpdir
}

run_render_request_pattern_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment request-patterns \
    --case uneven-size-mix \
    --profile default \
    --report "${TEST_TMPDIR}/request-patterns-report.md" \
    --json-report "${TEST_TMPDIR}/request-patterns-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should render the request-pattern report scaffold"
  assert_file_exists "${TEST_TMPDIR}/request-patterns-report.md" "render-report should write the request-pattern Markdown report"
  assert_file_exists "${TEST_TMPDIR}/request-patterns-report.json" "render-report should write the request-pattern JSON report"

  REQUEST_PATTERN_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/request-patterns-report.md")
  REQUEST_PATTERN_JSON_CONTENT=$(cat "${TEST_TMPDIR}/request-patterns-report.json")

  assert_contains "${REQUEST_PATTERN_REPORT_CONTENT}" "# Request Pattern Utilization - uneven-size-mix" "request-pattern report should include the experiment title and case"
  assert_contains "${REQUEST_PATTERN_REPORT_CONTENT}" "| Request shapes | short:128/64 weight=6, medium:512/128 weight=3, long:1536/512 weight=1 |" "request-pattern report should include the mixed request shapes"
  assert_contains "${REQUEST_PATTERN_JSON_CONTENT}" "\"name\": \"request-patterns\"" "request-pattern JSON report should include the experiment name"
  assert_contains "${REQUEST_PATTERN_JSON_CONTENT}" '"request_shapes": [{"id":"short","prompt_token_target":128,"max_tokens":64,"weight":6}, {"id":"medium","prompt_token_target":512,"max_tokens":128,"weight":3}, {"id":"long","prompt_token_target":1536,"max_tokens":512,"weight":1}]' "request-pattern JSON report should persist weighted request shapes"

  teardown_test_tmpdir
}

run_render_autoscaling_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment autoscaling \
    --case burst-queued \
    --profile default \
    --report "${TEST_TMPDIR}/autoscaling-report.md" \
    --json-report "${TEST_TMPDIR}/autoscaling-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should render the autoscaling report scaffold"
  assert_file_exists "${TEST_TMPDIR}/autoscaling-report.md" "render-report should write the autoscaling Markdown report"
  assert_file_exists "${TEST_TMPDIR}/autoscaling-report.json" "render-report should write the autoscaling JSON report"

  AUTOSCALING_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/autoscaling-report.md")
  AUTOSCALING_JSON_CONTENT=$(cat "${TEST_TMPDIR}/autoscaling-report.json")

  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "# Autoscaling And Queueing Behavior - burst-queued" "autoscaling report should include the experiment title and case"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Client policy | bounded-queue |" "autoscaling report should include the bounded queue policy"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Load executor | ramping-vus |" "autoscaling report should include the queued load executor"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Buffer capacity | 240 requests |" "autoscaling report should include buffer capacity"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Start load | 1 VUs |" "autoscaling report should label queued load as VUs"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Dropped client iterations | n/a |" "autoscaling report should include dropped client iterations"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Interrupted client iterations | n/a |" "autoscaling report should include interrupted client iterations"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Buffering required | n/a |" "autoscaling report should include buffering required"
  assert_contains "${AUTOSCALING_REPORT_CONTENT}" "| Pod scheduled | n/a |" "autoscaling report should include pod scheduling timing"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"name\": \"autoscaling\"" "autoscaling JSON report should include the experiment name"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"client_policy\": {" "autoscaling JSON report should include client policy metadata"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"id\": \"bounded-queue\"" "autoscaling JSON report should include the bounded queue policy id"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"executor\": \"ramping-vus\"" "autoscaling JSON report should include the queued executor"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"buffer_capacity_requests\": 240" "autoscaling JSON report should include buffer capacity"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"interrupted_iterations\": null" "autoscaling JSON report should include interrupted iteration result field"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"buffering_required_requests\": null" "autoscaling JSON report should include buffering required result field"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"failure_attribution\": null" "autoscaling JSON report should include failure attribution"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"pod_scheduled_seconds\": null" "autoscaling JSON report should include pod scheduling timing"
  assert_contains "${AUTOSCALING_JSON_CONTENT}" "\"container_started_seconds\": null" "autoscaling JSON report should include container startup timing"

  teardown_test_tmpdir
}

run_render_cost_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment cost \
    --case steady-cost-efficiency \
    --profile optimized-batched \
    --report "${TEST_TMPDIR}/cost-report.md" \
    --json-report "${TEST_TMPDIR}/cost-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should render the cost report scaffold"
  assert_file_exists "${TEST_TMPDIR}/cost-report.md" "render-report should write the cost Markdown report"
  assert_file_exists "${TEST_TMPDIR}/cost-report.json" "render-report should write the cost JSON report"

  COST_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/cost-report.md")
  COST_JSON_CONTENT=$(cat "${TEST_TMPDIR}/cost-report.json")

  assert_contains "${COST_REPORT_CONTENT}" "# Cost Per Useful Work - steady-cost-efficiency" "cost report should include the experiment title and case"
  assert_contains "${COST_REPORT_CONTENT}" "| Profile | optimized-batched |" "cost report should include the optimized profile"
  assert_contains "${COST_REPORT_CONTENT}" "| Cost scope | serving-gpu-only |" "cost report should include the cost scope"
  assert_contains "${COST_REPORT_CONTENT}" "| Serving hourly cost | 0.526 |" "cost report should include the serving hourly cost"
  assert_contains "${COST_REPORT_CONTENT}" "| p95 request SLO | 2.0 |" "cost report should include the p95 SLO target"
  assert_contains "${COST_REPORT_CONTENT}" "| Successful requests | n/a |" "cost report should include successful requests"
  assert_contains "${COST_REPORT_CONTENT}" "| Generated tokens | n/a |" "cost report should include generated tokens"
  assert_contains "${COST_REPORT_CONTENT}" "| SLO passed | n/a |" "cost report should include SLO status"
  assert_contains "${COST_JSON_CONTENT}" "\"name\": \"cost\"" "cost JSON report should include the experiment name"
  assert_contains "${COST_JSON_CONTENT}" "\"cost_profile\": {" "cost JSON report should include cost profile metadata"
  assert_contains "${COST_JSON_CONTENT}" "\"cost_scope\": \"serving-gpu-only\"" "cost JSON report should include the cost scope"
  assert_contains "${COST_JSON_CONTENT}" "\"serving_hourly_cost_usd\": 0.526" "cost JSON report should include the serving hourly cost"
  assert_contains "${COST_JSON_CONTENT}" "\"slo_p95_request_latency_seconds\": 2.0" "cost JSON report should include the p95 SLO"
  assert_contains "${COST_JSON_CONTENT}" "\"successful_requests\": null" "cost JSON report should include successful requests"
  assert_contains "${COST_JSON_CONTENT}" "\"generated_tokens\": null" "cost JSON report should include generated tokens"
  assert_contains "${COST_JSON_CONTENT}" "\"passed\": null" "cost JSON report should include SLO pass/fail"

  teardown_test_tmpdir
}

run_render_fp4_report_test() {
  setup_test_tmpdir

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment fp4 \
    --case steady-512-output-128 \
    --profile nvfp4-smoothquant \
    --report "${TEST_TMPDIR}/fp4-report.md" \
    --json-report "${TEST_TMPDIR}/fp4-report.json"

  assert_status 0 "${COMMAND_STATUS}" "render-report should render the FP4 report scaffold"
  assert_file_exists "${TEST_TMPDIR}/fp4-report.md" "render-report should write the FP4 Markdown report"
  assert_file_exists "${TEST_TMPDIR}/fp4-report.json" "render-report should write the FP4 JSON report"

  FP4_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/fp4-report.md")
  FP4_JSON_CONTENT=$(cat "${TEST_TMPDIR}/fp4-report.json")

  assert_contains "${FP4_REPORT_CONTENT}" "# FP4 Quantization Optimization - steady-512-output-128" "FP4 report should include the experiment title and case"
  assert_contains "${FP4_REPORT_CONTENT}" "| Dtype | auto |" "FP4 report should include dtype metadata"
  assert_contains "${FP4_REPORT_CONTENT}" "| Tensor parallel size | 8 |" "FP4 report should include tensor parallel metadata"
  assert_contains "${FP4_REPORT_CONTENT}" "| Node profile | blackwell |" "FP4 report should include Blackwell metadata"
  assert_contains "${FP4_REPORT_CONTENT}" "| Method | nvfp4+smoothquant |" "FP4 report should include the quantization method"
  assert_contains "${FP4_REPORT_CONTENT}" "| Calibration settings | dataset=HuggingFaceH4/ultrachat_200k split=train_sft samples=512 max_seq_len=2048 seed=42 |" "FP4 report should include calibration settings"
  assert_contains "${FP4_REPORT_CONTENT}" "| Tasks | arc_easy, hellaswag, winogrande |" "FP4 report should include accuracy tasks"
  assert_contains "${FP4_REPORT_CONTENT}" "| Cost source | aws-ec2-capacity-blocks-ml |" "FP4 report should include the configurable cost source"
  assert_contains "${FP4_REPORT_CONTENT}" "| Instance hourly cost | 82.368 |" "FP4 report should include the p6-b200 instance cost"
  assert_contains "${FP4_REPORT_CONTENT}" "| Accelerator hourly cost | 10.296 |" "FP4 report should include the B200 accelerator cost"
  assert_contains "${FP4_REPORT_CONTENT}" "| Quantization build cost | 123.552000 |" "FP4 report should keep build cost separate"
  assert_contains "${FP4_REPORT_CONTENT}" "| SmoothQuant gain vs plain NVFP4 | n/a |" "FP4 report should include SmoothQuant gain placeholder"
  assert_contains "${FP4_JSON_CONTENT}" "\"name\": \"fp4\"" "FP4 JSON report should include the experiment name"
  assert_contains "${FP4_JSON_CONTENT}" "\"dtype\": \"auto\"" "FP4 JSON report should include dtype metadata"
  assert_contains "${FP4_JSON_CONTENT}" "\"tensor_parallel_size\": 8" "FP4 JSON report should include tensor parallel metadata"
  assert_contains "${FP4_JSON_CONTENT}" "\"method\": \"nvfp4+smoothquant\"" "FP4 JSON report should include quantization method"
  assert_contains "${FP4_JSON_CONTENT}" "\"recipe_hash\": \"sha256:a4da9963fc9cbbf4fc446015f586a6c0a8828f31a4314ec3c9e69775fad8a1a7\"" "FP4 JSON report should include the recipe hash"
  assert_contains "${FP4_JSON_CONTENT}" "\"tasks\": \"arc_easy|hellaswag|winogrande\"" "FP4 JSON report should include accuracy tasks"
  assert_contains "${FP4_JSON_CONTENT}" "\"instance_type\": \"p6-b200.48xlarge\"" "FP4 JSON report should include the cost instance type"
  assert_contains "${FP4_JSON_CONTENT}" "\"cost_per_1k_successful_requests_usd\": null" "FP4 JSON report should include the requested request cost field"
  assert_contains "${FP4_JSON_CONTENT}" "\"cost_per_accuracy_recovered_percent_usd\": null" "FP4 JSON report should include the requested recovery cost field"
  assert_contains "${FP4_JSON_CONTENT}" "\"quantization_build_cost_usd\": 123.552000" "FP4 JSON report should include quantization build cost"

  teardown_test_tmpdir
}

run_render_report_default_path_test() {
  setup_test_tmpdir

  run_and_capture env \
    EXPERIMENT_REPORTS_DIR="${TEST_TMPDIR}/docs/reports" \
    /bin/bash "${REPO_ROOT}/scripts/experiment" render-report \
    --experiment kv-cache \
    --case prompt-512-output-100 \
    --profile default

  assert_status 0 "${COMMAND_STATUS}" "render-report should write default report paths"
  assert_contains "${COMMAND_OUTPUT}" "${TEST_TMPDIR}/docs/reports/experiment-kv-cache-prompt-512-output-100-default-" "render-report should default into docs/reports"

  DEFAULT_REPORT_COUNT=$(find "${TEST_TMPDIR}/docs/reports" -name 'experiment-kv-cache-prompt-512-output-100-default-*.md' | wc -l | tr -d ' ')
  DEFAULT_JSON_COUNT=$(find "${TEST_TMPDIR}/docs/reports" -name 'experiment-kv-cache-prompt-512-output-100-default-*.json' | wc -l | tr -d ' ')

  assert_eq "1" "${DEFAULT_REPORT_COUNT}" "render-report should create one default Markdown report"
  assert_eq "1" "${DEFAULT_JSON_COUNT}" "render-report should create one default JSON report"

  teardown_test_tmpdir
}

run_summarize_reports_test() {
  setup_test_tmpdir
  mkdir -p "${TEST_TMPDIR}/reports"

  printf '%s\n' \
    '{"schema_version":"experiment-report/v1","experiment":{"name":"kv-cache","title":"KV Cache Vs Concurrency"},"case":{"id":"prompt-8192-output-300-rate-100","prompt_token_target":8192,"max_tokens":300,"arrival":{"target_rate":1.00}},"serving_profile":{"id":"long-context"},"run":{"status":"complete","generated_at":"2026-05-02T23:07:02Z"},"results":{"success":{"successful_requests":599,"failed_requests":0},"latency":{"p95_request_latency_seconds":13.61},"serving":{"requests_per_second":0.83},"queue":{"dropped_iterations":0,"interrupted_iterations":0,"buffering_required_requests":0,"delivery_ratio":1,"peak_waiting_requests":0,"peak_active_requests":13},"gpu":{"average_gpu_utilization_percent":23.1,"max_gpu_utilization_percent":91}}}' \
    > "${TEST_TMPDIR}/reports/experiment-kv-cache-prompt-8192-output-300-rate-100-long-context-old.json"
  printf '%s\n' \
    '{"schema_version":"experiment-report/v1","experiment":{"name":"kv-cache","title":"KV Cache Vs Concurrency"},"case":{"id":"prompt-8192-output-300-rate-100","prompt_token_target":8192,"max_tokens":300,"arrival":{"target_rate":1.00}},"serving_profile":{"id":"long-context"},"run":{"status":"complete","generated_at":"2026-05-02T23:29:14Z"},"results":{"success":{"successful_requests":601,"failed_requests":0},"latency":{"p95_request_latency_seconds":12.50},"serving":{"requests_per_second":0.84},"queue":{"dropped_iterations":0,"interrupted_iterations":0,"buffering_required_requests":0,"delivery_ratio":1,"peak_waiting_requests":0,"peak_active_requests":12},"gpu":{"average_gpu_utilization_percent":58.4,"max_gpu_utilization_percent":96}}}' \
    > "${TEST_TMPDIR}/reports/experiment-kv-cache-prompt-8192-output-300-rate-100-long-context-new.json"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" summarize-reports \
    --experiment kv-cache \
    --reports-dir "${TEST_TMPDIR}/reports"

  assert_status 0 "${COMMAND_STATUS}" "summarize-reports should summarize available experiment reports"
  assert_contains "${COMMAND_OUTPUT}" "# KV Cache Vs Concurrency Report Summary" "summary should include the experiment title"
  assert_contains "${COMMAND_OUTPUT}" "| \`prompt-8192-output-300-rate-100\` | \`long-context\` | complete | 1.00 | 601 | 0 | 0 | 0 | 0 | 1 | 12.50 | 0.84 | 0 | 12 | 58.4 | 96 |" "summary should keep the latest report per case/profile"
  assert_not_contains "${COMMAND_OUTPUT}" "599" "summary should not show superseded older reports for the same case/profile"

  teardown_test_tmpdir
}

write_experiment_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-serving.yaml\"" \
"    exit 0" \
"    ;;" \
  "  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
  "  'get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.10'; exit 0 ;;" \
  "  apply\\ -f\\ /tmp/gpu-lab-experiment-load.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-load.yaml\"" \
"    exit 0" \
"    ;;" \
"  get\\ job/kv-cache-prompt-512-output-100\\ -n\\ app\\ -o\\ jsonpath=*Complete*) printf '%s\n' 'True'; exit 0 ;;" \
"  'logs -n app job/kv-cache-prompt-512-output-100')" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_BEGIN'" \
"    printf '%s\n' 'completed_requests=42'" \
"    printf '%s\n' 'failed_requests=1'" \
"    printf '%s\n' 'dropped_iterations=3'" \
"    printf '%s\n' 'interrupted_iterations=2'" \
"    printf '%s\n' 'buffering_required_requests=3'" \
"    printf '%s\n' 'generated_tokens=4096'" \
"    printf '%s\n' 'p50_request_latency_seconds=0.25'" \
"    printf '%s\n' 'p95_request_latency_seconds=0.75'" \
"    printf '%s\n' 'p99_request_latency_seconds=1.5'" \
"    printf '%s\n' 'requests_per_second=5.5'" \
"    printf '%s\n' 'generation_tokens_per_second=704'" \
	"    printf '%s\n' 'run_duration_seconds=120'" \
	"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_END'" \
	"    printf '%s\n' 'running (02m00.0s), 000/128 VUs, 42 complete and 7 interrupted iterations'" \
	"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-load.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

write_experiment_run_curl_stub() {
  write_stub curl \
"#!/usr/bin/env bash" \
  "set -euo pipefail" \
  "printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
  "cmd=\"\$*\"" \
  "if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
  "  value=''" \
  "  if [[ \"\$cmd\" == *'count(DCGM_FI_DEV_GPU_UTIL)'* ]]; then" \
  "    value='1'" \
  "  elif [[ \"\$cmd\" == *'count(DCGM_FI_DEV_FB_USED)'* ]]; then" \
  "    value='1'" \
  "  elif [[ \"\$cmd\" == *'count(DCGM_FI_DEV_FB_FREE)'* ]]; then" \
  "    value='1'" \
  "  elif [[ \"\$cmd\" == *'num_requests_running'* && \"\$cmd\" == *'num_requests_waiting'* ]]; then" \
  "    value='11'" \
  "  elif [[ \"\$cmd\" == *'num_requests_waiting'* ]]; then" \
  "    value='2'" \
"  elif [[ \"\$cmd\" == *'num_requests_running'* ]]; then" \
"    value='9'" \
"  elif [[ \"\$cmd\" == *'avg_over_time((avg(DCGM_FI_DEV_GPU_UTIL))'* ]]; then" \
"    value='63.5'" \
"  elif [[ \"\$cmd\" == *'max_over_time((max(DCGM_FI_DEV_GPU_UTIL))'* ]]; then" \
"    value='88.2'" \
"  elif [[ \"\$cmd\" == *'DCGM_FI_DEV_FB_USED'* ]]; then" \
"    value='4294967296'" \
"  elif [[ \"\$cmd\" == *'DCGM_FI_DEV_FB_FREE'* ]]; then" \
"    value='8589934592'" \
"  fi" \
"  printf '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"%s\"]}]}}' \"\$value\"" \
"  exit 0" \
"fi" \
"printf '200'"
}

run_live_experiment_runner_test() {
  setup_test_tmpdir
  write_experiment_run_kubectl_stub
  write_experiment_run_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment kv-cache \
    --case prompt-512-output-100 \
    --profile default \
    --report "${TEST_TMPDIR}/run.md" \
    --json-report "${TEST_TMPDIR}/run.json"

  assert_status 0 "${COMMAND_STATUS}" "experiment run should complete when the load job succeeds"
  assert_contains "${COMMAND_OUTPUT}" "Experiment run status: complete" "run output should summarize the complete status"
  assert_contains "${COMMAND_OUTPUT}" "K6 log: ${TEST_TMPDIR}/run.k6.log" "run output should print the k6 log path"
  assert_file_exists "${TEST_TMPDIR}/run.md" "experiment run should write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/run.json" "experiment run should write a JSON report"
  assert_file_exists "${TEST_TMPDIR}/run.k6.log" "experiment run should persist k6 logs next to the JSON report"
  assert_file_exists "${TEST_TMPDIR}/applied-serving.yaml" "experiment run should apply a rendered serving manifest"
  assert_file_exists "${TEST_TMPDIR}/applied-load.yaml" "experiment run should apply a rendered load manifest"

  RUN_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/run.md")
  RUN_JSON_CONTENT=$(cat "${TEST_TMPDIR}/run.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")

  assert_contains "${RUN_REPORT_CONTENT}" "Status: complete" "experiment run should mark the Markdown report complete"
  assert_contains "${RUN_REPORT_CONTENT}" "| Completed requests | 42 |" "experiment run should parse completed requests from k6 logs"
  assert_contains "${RUN_REPORT_CONTENT}" "| Successful requests | 41 |" "experiment run should derive successful requests from completed minus failed"
  assert_contains "${RUN_REPORT_CONTENT}" "| Offered client iterations | 52 |" "experiment run should derive offered client iterations from completed and unmet demand"
  assert_contains "${RUN_REPORT_CONTENT}" "| Unserved client iterations | 11 |" "experiment run should derive unserved client iterations from failed, dropped, and interrupted work"
  assert_contains "${RUN_REPORT_CONTENT}" "| Delivery ratio | 0.788462 |" "experiment run should derive a successful-delivery ratio"
  assert_contains "${RUN_REPORT_CONTENT}" "| Interrupted client iterations | 7 |" "experiment run should prefer the final k6 footer interrupted count when it exceeds the summary"
  assert_contains "${RUN_REPORT_CONTENT}" "| p99 request latency | 1.5 |" "experiment run should parse p99 latency from k6 logs"
  assert_contains "${RUN_REPORT_CONTENT}" "| Generated tokens | 4096 |" "experiment run should parse generated token totals from k6 logs"
  assert_contains "${RUN_REPORT_CONTENT}" "| Run duration | 120 |" "experiment run should parse run duration from k6 logs"
  assert_contains "${RUN_JSON_CONTENT}" "\"status\": \"complete\"" "experiment run should mark the JSON report complete"
  assert_contains "${RUN_JSON_CONTENT}" "\"source\": \"scripts/experiment run\"" "experiment run should record the live runner source"
  assert_contains "${RUN_JSON_CONTENT}" "\"completed_requests\": 42" "experiment run should write completed requests to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"successful_requests\": 41" "experiment run should write successful requests to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"failed_requests\": 1" "experiment run should write failed requests to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"offered_iterations\": 52" "experiment run should write offered iterations to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"unserved_iterations\": 11" "experiment run should write unserved iterations to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"delivery_ratio\": 0.788462" "experiment run should write delivery ratio to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"dropped_iterations\": 3" "experiment run should write dropped iterations to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"interrupted_iterations\": 7" "experiment run should write merged interrupted iterations to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"buffering_required_requests\": 10" "experiment run should count dropped and interrupted work as buffering pressure"
  assert_contains "${RUN_JSON_CONTENT}" "\"failure_attribution\": \"client_queue_limit\"" "experiment run should attribute dropped iterations to the client queue limit"
  assert_contains "${RUN_JSON_CONTENT}" "\"oom_events\": null" "experiment run should leave OOM events null when pod status has no termination reason"
  assert_contains "${RUN_JSON_CONTENT}" "\"p95_request_latency_seconds\": 0.75" "experiment run should write p95 latency to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"requests_per_second\": 5.5" "experiment run should write request throughput to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"generated_tokens\": 4096" "experiment run should write generated tokens to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"generation_tokens_per_second\": 704" "experiment run should write generation token throughput to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"run_duration_seconds\": 120" "experiment run should write run duration to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"peak_waiting_requests\": 2" "experiment run should collect waiting-request pressure when Prometheus is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"peak_running_requests\": 9" "experiment run should collect running-request pressure when Prometheus is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"peak_active_requests\": 11" "experiment run should collect active-request pressure when Prometheus is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"average_gpu_utilization_percent\": 63.5" "experiment run should collect average GPU utilization when DCGM is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"max_gpu_utilization_percent\": 88.2" "experiment run should collect max GPU utilization when DCGM is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"gpu_memory_used_bytes\": 4294967296" "experiment run should collect GPU memory used when DCGM is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"gpu_memory_free_bytes\": 8589934592" "experiment run should collect GPU memory free when DCGM is available"
  assert_contains "${RUN_JSON_CONTENT}" "\"cost_per_1000_successful_requests_usd\": null" "experiment run should leave cost null without a cost profile"
  assert_occurs_before "${KUBECTL_LOG}" \
    "apply -f ${REPO_ROOT}/platform/inference/service.yaml" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "experiment run should apply the service before waiting for serving readiness"
  assert_occurs_before "${KUBECTL_LOG}" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}" \
    "experiment run should wait for a live DCGM exporter endpoint after serving readiness"
  assert_occurs_before "${KUBECTL_LOG}" \
    "get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}" \
    "port-forward -n monitoring service/kube-prometheus-stack-prometheus :9090" \
    "experiment run should check Prometheus after finding a DCGM endpoint"
  assert_occurs_before "${KUBECTL_LOG}" \
    "port-forward -n monitoring service/kube-prometheus-stack-prometheus :9090" \
    "apply -f /tmp/gpu-lab-experiment-load." \
    "experiment run should verify DCGM metrics before starting load"
  assert_occurs_before "${KUBECTL_LOG}" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "get job/kv-cache-prompt-512-output-100 -n app -o jsonpath=" \
    "experiment run should wait for serving readiness before waiting on load"
  assert_contains "${CURL_LOG}" "query=count(DCGM_FI_DEV_GPU_UTIL)" "experiment run should verify DCGM GPU utilization is scrapeable before load"
  assert_contains "${CURL_LOG}" "query=count(DCGM_FI_DEV_FB_USED)" "experiment run should verify DCGM used-memory metrics are scrapeable before load"
  assert_contains "${CURL_LOG}" "query=count(DCGM_FI_DEV_FB_FREE)" "experiment run should verify DCGM free-memory metrics are scrapeable before load"
  assert_contains "${CURL_LOG}" "time=" "experiment run should anchor final Prometheus queries to the observed load window"
  assert_contains "${KUBECTL_LOG}" "delete -f /tmp/gpu-lab-experiment-load." "experiment run should clean up the rendered load manifest"
  assert_contains "${KUBECTL_LOG}" "delete -f /tmp/gpu-lab-experiment-serving." "experiment run should clean up the rendered serving manifest"

  teardown_test_tmpdir
}

write_autoscaling_experiment_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == *\"get nodeclaims\"*\"--sort-by=.metadata.creationTimestamp\"* ]]; then" \
"  printf '%s\n' 'gpu-serving-ondemand-test'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == *\"get nodeclaims\"*\"-o name\"* ]]; then" \
"  printf '%s\n' 'nodeclaim/gpu-serving-ondemand-test'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == 'get nodeclaim gpu-serving-ondemand-test -o jsonpath={.metadata.creationTimestamp}' ]]; then" \
"  printf '%s\n' '2020-01-01T00:00:00Z'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == *\"get nodes -l workload=gpu\"*\"--sort-by=.metadata.creationTimestamp\"* ]]; then" \
"  printf '%s\n' 'ip-10-0-0-42.us-west-2.compute.internal Ready <none> 1m v1.35.2'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == *\"get nodes -l workload=gpu\"*\"-o name\"* ]]; then" \
"  printf '%s\n' 'node/ip-10-0-0-42.us-west-2.compute.internal'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == 'get node ip-10-0-0-42.us-west-2.compute.internal -o jsonpath={.metadata.creationTimestamp}' ]]; then" \
"  printf '%s\n' '2020-01-01T00:00:30Z'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == *\"get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp\"* ]]; then" \
"  printf '%s\n' 'vllm-openai-test'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == 'get pod vllm-openai-test -n app -o jsonpath={.status.conditions[?(@.type=='\"'\"'PodScheduled'\"'\"')].status}' ]]; then" \
"  printf '%s\n' 'True'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == 'get pod vllm-openai-test -n app -o jsonpath={.status.conditions[?(@.type=='\"'\"'PodScheduled'\"'\"')].lastTransitionTime}' ]]; then" \
"  printf '%s\n' '2020-01-01T00:01:00Z'" \
"  exit 0" \
"fi" \
"if [[ \"\${cmd}\" == 'get pod vllm-openai-test -n app -o jsonpath={.status.containerStatuses[0].state.running.startedAt}' ]]; then" \
"  printf '%s\n' '2020-01-01T00:02:00Z'" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-serving.yaml\"" \
"    exit 0" \
"    ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.10'; exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-load.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-load.yaml\"" \
"    exit 0" \
"    ;;" \
"  get\\ job/autoscaling-spike-queued\\ -n\\ app\\ -o\\ jsonpath=*Complete*) printf '%s\n' 'True'; exit 0 ;;" \
"  'logs -n app job/autoscaling-spike-queued')" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_BEGIN'" \
"    printf '%s\n' 'completed_requests=24'" \
"    printf '%s\n' 'failed_requests=0'" \
"    printf '%s\n' 'dropped_iterations=0'" \
"    printf '%s\n' 'interrupted_iterations=0'" \
"    printf '%s\n' 'buffering_required_requests=0'" \
"    printf '%s\n' 'generated_tokens=3072'" \
"    printf '%s\n' 'p95_request_latency_seconds=2.5'" \
"    printf '%s\n' 'requests_per_second=6'" \
"    printf '%s\n' 'generation_tokens_per_second=768'" \
"    printf '%s\n' 'run_duration_seconds=110'" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_END'" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-load.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

run_autoscaling_experiment_runner_timeline_test() {
  setup_test_tmpdir
  write_autoscaling_experiment_run_kubectl_stub
  write_experiment_run_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment autoscaling \
    --case spike-queued \
    --profile default \
    --report "${TEST_TMPDIR}/autoscaling-run.md" \
    --json-report "${TEST_TMPDIR}/autoscaling-run.json"

  assert_status 0 "${COMMAND_STATUS}" "autoscaling experiment run should complete when the load job succeeds"
  assert_file_exists "${TEST_TMPDIR}/autoscaling-run.md" "autoscaling run should write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/autoscaling-run.json" "autoscaling run should write a JSON report"

  AUTOSCALING_RUN_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/autoscaling-run.md")
  AUTOSCALING_RUN_JSON_CONTENT=$(cat "${TEST_TMPDIR}/autoscaling-run.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")

  assert_contains "${AUTOSCALING_RUN_REPORT_CONTENT}" "| First NodeClaim | 0 |" "autoscaling run should record first NodeClaim timing"
  assert_contains "${AUTOSCALING_RUN_REPORT_CONTENT}" "| First GPU node | 0 |" "autoscaling run should record first GPU node timing"
  assert_contains "${AUTOSCALING_RUN_REPORT_CONTENT}" "| Pod scheduled | 0 |" "autoscaling run should record pod scheduling timing"
  assert_contains "${AUTOSCALING_RUN_REPORT_CONTENT}" "| Container started | 0 |" "autoscaling run should record container startup timing"
  assert_contains "${AUTOSCALING_RUN_JSON_CONTENT}" "\"first_nodeclaim_seconds\": 0" "autoscaling JSON should include first NodeClaim timing"
  assert_contains "${AUTOSCALING_RUN_JSON_CONTENT}" "\"first_gpu_node_seconds\": 0" "autoscaling JSON should include first GPU node timing"
  assert_contains "${AUTOSCALING_RUN_JSON_CONTENT}" "\"pod_scheduled_seconds\": 0" "autoscaling JSON should include pod scheduling timing"
  assert_contains "${AUTOSCALING_RUN_JSON_CONTENT}" "\"container_started_seconds\": 0" "autoscaling JSON should include container startup timing"
  assert_not_contains "${AUTOSCALING_RUN_JSON_CONTENT}" "\"model_ready_seconds\": null" "autoscaling JSON should include model readiness timing"
  assert_occurs_before "${KUBECTL_LOG}" \
    "apply -f /tmp/gpu-lab-experiment-serving." \
    "get nodeclaims -l" \
    "autoscaling run should start timeline collection immediately after applying serving"
  assert_occurs_before "${KUBECTL_LOG}" \
    "get pod vllm-openai-test -n app -o jsonpath={.status.containerStatuses[0].state.running.startedAt}" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "autoscaling run should capture container startup before marking the model ready"

  teardown_test_tmpdir
}

write_cost_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-serving.yaml\"" \
"    exit 0" \
"    ;;" \
  "  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
  "  'get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.10'; exit 0 ;;" \
  "  apply\\ -f\\ /tmp/gpu-lab-experiment-load.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-load.yaml\"" \
"    exit 0" \
"    ;;" \
"  get\\ job/cost-steady-cost-efficiency\\ -n\\ app\\ -o\\ jsonpath=*Complete*) printf '%s\n' 'True'; exit 0 ;;" \
"  'logs -n app job/cost-steady-cost-efficiency')" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_BEGIN'" \
"    printf '%s\n' 'completed_requests=100'" \
"    printf '%s\n' 'failed_requests=4'" \
"    printf '%s\n' 'dropped_iterations=0'" \
"    printf '%s\n' 'interrupted_iterations=0'" \
"    printf '%s\n' 'buffering_required_requests=0'" \
"    printf '%s\n' 'generated_tokens=8000'" \
"    printf '%s\n' 'p50_request_latency_seconds=0.6'" \
"    printf '%s\n' 'p95_request_latency_seconds=1.25'" \
"    printf '%s\n' 'p99_request_latency_seconds=4.5'" \
"    printf '%s\n' 'requests_per_second=10'" \
"    printf '%s\n' 'generation_tokens_per_second=800'" \
"    printf '%s\n' 'run_duration_seconds=180'" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_END'" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-load.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

run_cost_experiment_runner_test() {
  setup_test_tmpdir
  write_cost_run_kubectl_stub
  write_experiment_run_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment cost \
    --case steady-cost-efficiency \
    --profile optimized-batched \
    --report "${TEST_TMPDIR}/cost-run.md" \
    --json-report "${TEST_TMPDIR}/cost-run.json"

  assert_status 0 "${COMMAND_STATUS}" "cost experiment run should complete when the load job succeeds"
  assert_contains "${COMMAND_OUTPUT}" "Experiment run status: complete" "cost run output should summarize the complete status"
  assert_file_exists "${TEST_TMPDIR}/cost-run.md" "cost run should write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/cost-run.json" "cost run should write a JSON report"

  COST_RUN_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/cost-run.md")
  COST_RUN_JSON_CONTENT=$(cat "${TEST_TMPDIR}/cost-run.json")

  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Completed requests | 100 |" "cost run should parse completed requests"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Successful requests | 96 |" "cost run should exclude failed requests from useful work"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Generated tokens | 8000 |" "cost run should parse generated tokens"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| SLO passed | true |" "cost run should derive SLO pass status"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Estimated burst cost | 0.026300 |" "cost run should estimate serving burst cost"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Cost per 1K successful requests | 0.273958 |" "cost run should derive request cost from successful requests"
  assert_contains "${COST_RUN_REPORT_CONTENT}" "| Cost per 1M generated tokens | 3.287500 |" "cost run should derive token cost from generated tokens"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"successful_requests\": 96" "cost run JSON should include successful requests"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"generated_tokens\": 8000" "cost run JSON should include generated tokens"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"passed\": true" "cost run JSON should include SLO pass status"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"estimated_burst_cost_usd\": 0.026300" "cost run JSON should include estimated burst cost"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"cost_per_1000_successful_requests_usd\": 0.273958" "cost run JSON should include cost per useful request"
  assert_contains "${COST_RUN_JSON_CONTENT}" "\"cost_per_1m_generated_tokens_usd\": 3.287500" "cost run JSON should include cost per generated token"

  teardown_test_tmpdir
}

write_missing_dcgm_curl_stub() {
  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
"if [[ \"\$*\" == *'/api/v1/query'* ]]; then" \
"  printf '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"0\"]}]}}'" \
"  exit 0" \
"fi" \
"printf '200'"
}

run_experiment_waits_for_dcgm_before_load_test() {
  setup_test_tmpdir
  write_experiment_run_kubectl_stub
  write_missing_dcgm_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    EXPERIMENT_DCGM_METRICS_TIMEOUT_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment kv-cache \
    --case prompt-512-output-100 \
    --profile default \
    --report "${TEST_TMPDIR}/missing-dcgm.md" \
    --json-report "${TEST_TMPDIR}/missing-dcgm.json"

  assert_status 1 "${COMMAND_STATUS}" "experiment run should fail before load when DCGM metrics never become scrapeable"
  assert_contains "${COMMAND_OUTPUT}" "Timed out waiting for DCGM GPU metrics in Prometheus" "experiment run should explain missing DCGM metrics"
  assert_file_exists "${TEST_TMPDIR}/applied-serving.yaml" "experiment run should still apply serving before checking DCGM"
  assert_file_not_exists "${TEST_TMPDIR}/applied-load.yaml" "experiment run should not start k6 load before DCGM is scrapeable"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")
  assert_contains "${KUBECTL_LOG}" "get daemonset dcgm-exporter -n monitoring -o wide" "experiment run should print DCGM daemonset diagnostics on missing metrics"
  assert_not_contains "${KUBECTL_LOG}" "apply -f /tmp/gpu-lab-experiment-load." "experiment run should not apply the load manifest when DCGM preflight fails"
  assert_contains "${CURL_LOG}" "query=count(DCGM_FI_DEV_GPU_UTIL)" "experiment run should query DCGM utilization availability"
  teardown_test_tmpdir
}

write_failed_experiment_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*) exit 0 ;;" \
  "  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
  "  'get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.10'; exit 0 ;;" \
  "  apply\\ -f\\ /tmp/gpu-lab-experiment-load.*) exit 0 ;;" \
"  get\\ job/kv-cache-prompt-512-output-100\\ -n\\ app\\ -o\\ jsonpath=*Complete*) exit 0 ;;" \
"  get\\ job/kv-cache-prompt-512-output-100\\ -n\\ app\\ -o\\ jsonpath=*Failed*.status*) printf '%s\n' 'True'; exit 0 ;;" \
"  get\\ job/kv-cache-prompt-512-output-100\\ -n\\ app\\ -o\\ jsonpath=*Failed*.reason*) printf '%s\n' 'BackoffLimitExceeded'; exit 0 ;;" \
"  get\\ job/kv-cache-prompt-512-output-100\\ -n\\ app\\ -o\\ jsonpath=*Failed*.message*) printf '%s\n' 'Job has reached the specified backoff limit'; exit 0 ;;" \
"  'logs -n app job/kv-cache-prompt-512-output-100')" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_BEGIN'" \
"    printf '%s\n' 'completed_requests=10'" \
"    printf '%s\n' 'failed_requests=10'" \
"    printf '%s\n' 'interrupted_iterations=0'" \
"    printf '%s\n' 'run_duration_seconds=60'" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_END'" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-load.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

run_failed_experiment_job_test() {
  setup_test_tmpdir
  write_failed_experiment_run_kubectl_stub
  write_experiment_run_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment kv-cache \
    --case prompt-512-output-100 \
    --profile default \
    --report "${TEST_TMPDIR}/failed.md" \
    --json-report "${TEST_TMPDIR}/failed.json"

  assert_status 1 "${COMMAND_STATUS}" "experiment run should fail when the load job reaches Failed"
  assert_contains "${COMMAND_OUTPUT}" "Job app/kv-cache-prompt-512-output-100 failed: BackoffLimitExceeded" "experiment run should report the job failure reason"
  assert_contains "${COMMAND_OUTPUT}" "Experiment run status: failed" "experiment run output should summarize failed status"
  assert_file_exists "${TEST_TMPDIR}/failed.md" "failed runs should still write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/failed.json" "failed runs should still write a JSON report"

  FAILED_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/failed.md")
  FAILED_JSON_CONTENT=$(cat "${TEST_TMPDIR}/failed.json")

  assert_contains "${FAILED_REPORT_CONTENT}" "Status: failed" "failed run should mark the Markdown report failed"
  assert_contains "${FAILED_REPORT_CONTENT}" "| Failed requests | 10 |" "failed run should still parse k6 logs"
  assert_contains "${FAILED_REPORT_CONTENT}" "| Dropped client iterations | 0 |" "failed run should normalize absent dropped iterations to zero once k6 emitted a summary"
  assert_contains "${FAILED_JSON_CONTENT}" "\"status\": \"failed\"" "failed run should mark JSON report failed"
  assert_contains "${FAILED_JSON_CONTENT}" "\"failed_requests\": 10" "failed run should write failed requests to JSON"
  assert_contains "${FAILED_JSON_CONTENT}" "\"dropped_iterations\": 0" "failed run should write normalized dropped iterations to JSON"
  assert_contains "${FAILED_JSON_CONTENT}" "\"buffering_required_requests\": 0" "failed run should write normalized buffering pressure to JSON"

  teardown_test_tmpdir
}

run_incompatible_case_profile_test() {
  setup_test_tmpdir
  write_experiment_run_kubectl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run \
    --experiment kv-cache \
    --case prompt-8192-output-300 \
    --profile default \
    --report "${TEST_TMPDIR}/bad.md" \
    --json-report "${TEST_TMPDIR}/bad.json"

  assert_status 1 "${COMMAND_STATUS}" "experiment run should reject incompatible context/profile combinations before kubectl"
  assert_contains "${COMMAND_OUTPUT}" "max_model_len 2048 is smaller than case prompt-8192-output-300 prompt+output budget 8492" "experiment run should explain incompatible max model length"
  assert_file_not_exists "${TEST_TMPDIR}/kubectl.log" "incompatible runs should fail before touching the cluster"

  teardown_test_tmpdir
}

write_stream_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-serving.yaml\"" \
"    exit 0" \
"    ;;" \
  "  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
  "  'get endpointslice -n monitoring -l kubernetes.io/service-name=dcgm-exporter -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.10'; exit 0 ;;" \
  "  apply\\ -f\\ /tmp/gpu-lab-experiment-stream.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-stream.yaml\"" \
"    exit 0" \
"    ;;" \
"  get\\ job/prefill-decode-prefill-heavy-stream\\ -n\\ app\\ -o\\ jsonpath=*Complete*) printf '%s\n' 'True'; exit 0 ;;" \
"  'logs -n app job/prefill-decode-prefill-heavy-stream')" \
"    printf '%s\n' 'GPU_LAB_STREAM_SUMMARY_BEGIN'" \
"    printf '%s\n' 'stream_samples=5'" \
"    printf '%s\n' 'stream_concurrency=3'" \
"    printf '%s\n' 'stream_shape_summaries=[{\"id\":\"prefill-heavy\",\"prompt_token_target\":1536,\"max_tokens\":64,\"weight\":1,\"completed_requests\":5,\"failed_requests\":0,\"p50_request_latency_seconds\":1.25,\"p95_request_latency_seconds\":1.75,\"p99_request_latency_seconds\":1.95,\"p50_ttft_seconds\":0.12,\"p95_ttft_seconds\":0.20,\"p50_inter_token_latency_seconds\":0.01,\"p95_inter_token_latency_seconds\":0.03,\"generation_tokens_per_second\":42.5}]'" \
"    printf '%s\n' 'stream_shape_summary_row=| prefill-heavy | 1536 | 64 | 5 | 0 | 1.75 | 0.20 | 0.03 | 42.5 |'" \
"    printf '%s\n' 'completed_requests=5'" \
"    printf '%s\n' 'failed_requests=0'" \
"    printf '%s\n' 'p50_request_latency_seconds=1.25'" \
"    printf '%s\n' 'p95_request_latency_seconds=1.75'" \
"    printf '%s\n' 'p99_request_latency_seconds=1.95'" \
"    printf '%s\n' 'p50_ttft_seconds=0.12'" \
"    printf '%s\n' 'p95_ttft_seconds=0.20'" \
"    printf '%s\n' 'p50_inter_token_latency_seconds=0.01'" \
"    printf '%s\n' 'p95_inter_token_latency_seconds=0.03'" \
"    printf '%s\n' 'generation_tokens_per_second=42.5'" \
"    printf '%s\n' 'run_duration_seconds=6.5'" \
"    printf '%s\n' 'GPU_LAB_STREAM_SUMMARY_END'" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-stream.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

run_stream_experiment_runner_test() {
  setup_test_tmpdir
  write_stream_run_kubectl_stub
  write_experiment_run_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/experiment" run-stream \
    --experiment prefill-decode \
    --case prefill-heavy \
    --profile default \
    --samples 5 \
    --concurrency 3 \
    --report "${TEST_TMPDIR}/stream.md" \
    --json-report "${TEST_TMPDIR}/stream.json"

  assert_status 0 "${COMMAND_STATUS}" "run-stream should complete when the streaming job succeeds"
  assert_contains "${COMMAND_OUTPUT}" "Streaming experiment run status: complete" "run-stream output should summarize the complete status"
  assert_contains "${COMMAND_OUTPUT}" "Stream log: ${TEST_TMPDIR}/stream.stream.log" "run-stream output should print the stream log path"
  assert_file_exists "${TEST_TMPDIR}/stream.md" "run-stream should write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/stream.json" "run-stream should write a JSON report"
  assert_file_exists "${TEST_TMPDIR}/stream.stream.log" "run-stream should persist streaming logs next to the JSON report"
  assert_file_exists "${TEST_TMPDIR}/applied-stream.yaml" "run-stream should apply a rendered stream manifest"

  STREAM_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/stream.md")
  STREAM_JSON_CONTENT=$(cat "${TEST_TMPDIR}/stream.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")

  assert_contains "${STREAM_REPORT_CONTENT}" "Status: complete" "run-stream should mark the Markdown report complete"
  assert_contains "${STREAM_REPORT_CONTENT}" "| Stream samples | 5 |" "run-stream should record stream samples in the Markdown report"
  assert_contains "${STREAM_REPORT_CONTENT}" "| Stream concurrency | 3 |" "run-stream should record stream concurrency in the Markdown report"
  assert_contains "${STREAM_REPORT_CONTENT}" "| p50 TTFT | 0.12 |" "run-stream should parse p50 TTFT from stream logs"
  assert_contains "${STREAM_REPORT_CONTENT}" "| p95 inter-token latency | 0.03 |" "run-stream should parse p95 inter-token latency from stream logs"
  assert_contains "${STREAM_REPORT_CONTENT}" "## Stream Shape Results" "run-stream should include per-shape metrics in the Markdown report"
  assert_contains "${STREAM_REPORT_CONTENT}" "| prefill-heavy | 1536 | 64 | 5 | 0 | 1.75 | 0.20 | 0.03 | 42.5 |" "run-stream should render per-shape Markdown rows"
  assert_contains "${STREAM_JSON_CONTENT}" "\"source\": \"scripts/experiment run-stream\"" "run-stream should record the streaming runner source"
  assert_contains "${STREAM_JSON_CONTENT}" "\"stream\": {" "run-stream should write stream metadata to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"samples\": 5" "run-stream should write stream sample count to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"concurrency\": 3" "run-stream should write stream concurrency to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"completed_requests\": 5" "run-stream should write completed requests to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"successful_requests\": 5" "run-stream should derive successful requests"
  assert_contains "${STREAM_JSON_CONTENT}" "\"p50_ttft_seconds\": 0.12" "run-stream should write p50 TTFT to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"p95_ttft_seconds\": 0.20" "run-stream should write p95 TTFT to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"p50_inter_token_latency_seconds\": 0.01" "run-stream should write p50 inter-token latency to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"p95_inter_token_latency_seconds\": 0.03" "run-stream should write p95 inter-token latency to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"generation_tokens_per_second\": 42.5" "run-stream should write streamed chunk throughput to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"run_duration_seconds\": 6.5" "run-stream should write run duration to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"stream_shapes\": [{\"id\":\"prefill-heavy\"" "run-stream should write per-shape metrics to JSON"
  assert_contains "${STREAM_JSON_CONTENT}" "\"p95_ttft_seconds\":0.20" "run-stream should preserve per-shape TTFT metrics"
  assert_occurs_before "${KUBECTL_LOG}" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "get job/prefill-decode-prefill-heavy-stream -n app -o jsonpath=" \
    "run-stream should wait for serving readiness before waiting on the streaming job"
  assert_contains "${KUBECTL_LOG}" "delete -f /tmp/gpu-lab-experiment-stream." "run-stream should clean up the rendered stream manifest"

  teardown_test_tmpdir
}

run_experiment_list_test
run_experiment_validate_test
run_experiment_show_test
run_prefill_decode_show_test
run_batching_show_test
run_request_patterns_show_test
run_autoscaling_show_test
run_cost_show_test
run_fp4_show_test
run_render_load_test
run_render_fractional_arrival_rate_load_test
run_render_autoscaling_load_test
run_render_request_pattern_load_test
run_render_stream_test
run_render_mixed_stream_test
run_render_fp4_quantization_manifest_test
run_render_fp4_accuracy_manifest_test
run_render_unknown_case_test
run_render_default_serving_profile_test
run_render_long_context_serving_profile_test
run_render_fp8_kv_serving_profile_test
run_render_batching_serving_profile_test
run_render_fp4_serving_profile_test
run_render_unknown_serving_profile_test
run_render_report_test
run_render_fp8_kv_report_test
run_render_report_incompatible_profile_test
run_render_batching_report_test
run_render_request_pattern_report_test
run_render_autoscaling_report_test
run_render_cost_report_test
run_render_fp4_report_test
run_render_report_default_path_test
run_summarize_reports_test
run_live_experiment_runner_test
run_autoscaling_experiment_runner_timeline_test
run_cost_experiment_runner_test
run_experiment_waits_for_dcgm_before_load_test
run_failed_experiment_job_test
run_incompatible_case_profile_test
run_stream_experiment_runner_test
