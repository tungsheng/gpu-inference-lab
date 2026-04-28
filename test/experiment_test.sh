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
}

run_experiment_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" show kv-cache

  assert_status 0 "${COMMAND_STATUS}" "scripts/experiment show should succeed for kv-cache"
  assert_contains "${COMMAND_OUTPUT}" "Experiment: kv-cache" "show output should include the experiment name"
  assert_contains "${COMMAND_OUTPUT}" "prompt-512-output-100" "show output should include the short prompt case"
  assert_contains "${COMMAND_OUTPUT}" "prompt=512 output=100" "show output should include case token settings"
  assert_contains "${COMMAND_OUTPUT}" "prompt-8192-output-300" "show output should include the long prompt case"
  assert_contains "${COMMAND_OUTPUT}" "Serving profiles:" "show output should include serving profiles"
  assert_contains "${COMMAND_OUTPUT}" "long-context" "show output should include the long-context serving profile"
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
  assert_contains "${RENDERED_MANIFEST}" "GPU_LAB_K6_SUMMARY_BEGIN" "rendered manifest should emit a parseable k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "p99_request_latency_seconds=" "rendered manifest should include p99 latency in the k6 summary"
  assert_contains "${RENDERED_MANIFEST}" "summaryTrendStats" "rendered manifest should request p95 and p99 k6 summaries"
  assert_contains "${RENDERED_MANIFEST}" "value: http://vllm-openai.app.svc.cluster.local/v1/completions" "rendered manifest should target the in-cluster vLLM service"

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
  assert_contains "${SERVING_MANIFEST}" '- "8192"' "long-context manifest should raise max model length to 8192"
  assert_contains "${SERVING_MANIFEST}" '- --gpu-memory-utilization' "long-context manifest should include GPU memory utilization"
  assert_contains "${SERVING_MANIFEST}" '- "0.90"' "long-context manifest should raise GPU memory utilization"
  assert_contains "${SERVING_MANIFEST}" '- --max-num-seqs' "long-context manifest should include an explicit max sequence limit"
  assert_contains "${SERVING_MANIFEST}" '- "32"' "long-context manifest should include the max sequence value"
  assert_contains "${SERVING_MANIFEST}" '- --max-num-batched-tokens' "long-context manifest should include a batched-token limit"

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
  assert_contains "${REPORT_CONTENT}" "| Max model length | 8192 |" "Markdown report should include serving metadata"
  assert_contains "${REPORT_CONTENT}" "| p99 request latency | n/a |" "Markdown report should render unavailable metrics as n/a"
  assert_contains "${REPORT_CONTENT}" "| GPU memory used | n/a |" "Markdown report should render unavailable GPU memory metrics as n/a"
  assert_contains "${REPORT_CONTENT}" "Result fields remain \`n/a\` until a live cluster run collects k6" "Markdown report should keep the n/a note literal"
  assert_contains "${JSON_REPORT_CONTENT}" "\"schema_version\": \"experiment-report/v1\"" "JSON report should include the schema version"
  assert_contains "${JSON_REPORT_CONTENT}" "\"status\": \"pending\"" "JSON report should mark the scaffold as pending"
  assert_contains "${JSON_REPORT_CONTENT}" "\"requires_live_cluster\": true" "JSON report should state that measured results require a live cluster"
  assert_contains "${JSON_REPORT_CONTENT}" "\"prompt_token_target\": 8192" "JSON report should include workload metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"max_model_len\": 8192" "JSON report should include serving metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"max_num_seqs\": 32" "JSON report should include scheduler metadata"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p99_request_latency_seconds\": null" "JSON report should render unavailable latency as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"gpu_memory_used_bytes\": null" "JSON report should render unavailable GPU memory as null"
  assert_contains "${JSON_REPORT_CONTENT}" "\"cost_per_1000_successful_requests_usd\": null" "JSON report should render unavailable cost as null"

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

write_experiment_run_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"case \"\$cmd\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-serving.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-serving.yaml\"" \
"    exit 0" \
"    ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  apply\\ -f\\ /tmp/gpu-lab-experiment-load.*)" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-load.yaml\"" \
"    exit 0" \
"    ;;" \
"  'wait --for=condition=complete job/kv-cache-prompt-512-output-100 -n app --timeout=1200s') exit 0 ;;" \
"  'logs -n app job/kv-cache-prompt-512-output-100')" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_BEGIN'" \
"    printf '%s\n' 'completed_requests=42'" \
"    printf '%s\n' 'failed_requests=1'" \
"    printf '%s\n' 'p50_request_latency_seconds=0.25'" \
"    printf '%s\n' 'p95_request_latency_seconds=0.75'" \
"    printf '%s\n' 'p99_request_latency_seconds=1.5'" \
"    printf '%s\n' 'requests_per_second=5.5'" \
"    printf '%s\n' 'GPU_LAB_K6_SUMMARY_END'" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai -o jsonpath={range .items[*]}{range .status.containerStatuses[*]}{.state.terminated.reason}{\"\\n\"}{.lastState.terminated.reason}{\"\\n\"}{end}{end}') exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-load.*\\ --ignore-not-found=true) exit 0 ;;" \
"  delete\\ -f\\ /tmp/gpu-lab-experiment-serving.*\\ --ignore-not-found=true) exit 0 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"
}

run_live_experiment_runner_test() {
  setup_test_tmpdir
  write_experiment_run_kubectl_stub

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

  assert_contains "${RUN_REPORT_CONTENT}" "Status: complete" "experiment run should mark the Markdown report complete"
  assert_contains "${RUN_REPORT_CONTENT}" "| Completed requests | 42 |" "experiment run should parse completed requests from k6 logs"
  assert_contains "${RUN_REPORT_CONTENT}" "| p99 request latency | 1.5 |" "experiment run should parse p99 latency from k6 logs"
  assert_contains "${RUN_JSON_CONTENT}" "\"status\": \"complete\"" "experiment run should mark the JSON report complete"
  assert_contains "${RUN_JSON_CONTENT}" "\"source\": \"scripts/experiment run\"" "experiment run should record the live runner source"
  assert_contains "${RUN_JSON_CONTENT}" "\"completed_requests\": 42" "experiment run should write completed requests to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"failed_requests\": 1" "experiment run should write failed requests to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"oom_events\": null" "experiment run should leave OOM events null when pod status has no termination reason"
  assert_contains "${RUN_JSON_CONTENT}" "\"p95_request_latency_seconds\": 0.75" "experiment run should write p95 latency to JSON"
  assert_contains "${RUN_JSON_CONTENT}" "\"requests_per_second\": 5.5" "experiment run should write request throughput to JSON"
  assert_occurs_before "${KUBECTL_LOG}" \
    "apply -f ${REPO_ROOT}/platform/inference/service.yaml" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "experiment run should apply the service before waiting for serving readiness"
  assert_occurs_before "${KUBECTL_LOG}" \
    "rollout status deployment/vllm-openai -n app --timeout=20m" \
    "wait --for=condition=complete job/kv-cache-prompt-512-output-100 -n app --timeout=1200s" \
    "experiment run should wait for serving readiness before waiting on load"
  assert_contains "${KUBECTL_LOG}" "delete -f /tmp/gpu-lab-experiment-load." "experiment run should clean up the rendered load manifest"
  assert_contains "${KUBECTL_LOG}" "delete -f /tmp/gpu-lab-experiment-serving." "experiment run should clean up the rendered serving manifest"

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

run_experiment_list_test
run_experiment_show_test
run_render_load_test
run_render_unknown_case_test
run_render_default_serving_profile_test
run_render_long_context_serving_profile_test
run_render_unknown_serving_profile_test
run_render_report_test
run_render_report_default_path_test
run_live_experiment_runner_test
run_incompatible_case_profile_test
