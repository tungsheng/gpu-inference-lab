#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

REPORT_PATH="${TEST_TMPDIR}/reports/measurement.md"
JSON_REPORT_PATH="${TEST_TMPDIR}/reports/measurement.json"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" REPORT_PATH="${REPORT_PATH}" JSON_REPORT_PATH="${JSON_REPORT_PATH}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/measure-report.sh"

  timestamp_utc() { printf "%s\n" "2026-03-30T07:00:00Z"; }
  now_epoch() { printf "%s\n" "0"; }

  APP_NAMESPACE="app"
  DEPLOYMENT_NAME="vllm-openai"
  NODECLASS_NAME="gpu-serving"
  NODEPOOL_NAME="gpu-serving"
  POLL_INTERVAL_SECONDS=2
  MEASUREMENT_PROFILE="warm-1"
  first_gpu_node_instance_type="g4dn.xlarge"
  second_gpu_node_instance_type="g5.xlarge"
  PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS="2.45"
  PRODUCTION_P95_TTFT_SECONDS="0.81"
  PRODUCTION_PEAK_QUEUE_DEPTH="7"
  PRODUCTION_AVG_GENERATION_TOKENS_PER_SECOND="142.3"
  PRODUCTION_AVG_GPU_UTILIZATION_PERCENT="67.2"
  PRODUCTION_MAX_GPU_UTILIZATION_PERCENT="93"
  PRODUCTION_PEAK_NODECLAIMS="2"
  ESTIMATED_IDLE_COST_PER_HOUR="0.526"
  ESTIMATED_BURST_COST="0.088432"
  REPORT_PATH=${REPORT_PATH}
  JSON_REPORT_PATH=${JSON_REPORT_PATH}
  inference_edge_url() { printf "%s\n" "http://public-edge.example.com/v1/completions"; }

  EVENT_NAMES=(start_time edge_hostname_seen first_ready_seen first_external_completion_seen second_ready_seen load_test_applied load_test_deleted scale_in_node_seen inference_deleted all_gpu_nodes_removed)
  TIMELINE_EVENT_LABELS=(
    "Inference manifest applied"
    "Inference edge hostname available"
    "First serving pod ready"
    "First successful external completion"
    "Two serving replicas Ready"
    "Load test applied"
    "Load test removed"
    "Extra GPU node removed"
    "Inference manifest deleted"
    "All GPU nodes removed"
  )

  initialize_event_state
  start_time=100
  start_time_human="2026-03-30T07:00:00Z"
  edge_hostname_seen=120
  edge_hostname_seen_human="2026-03-30T07:00:20Z"
  first_ready_seen=160
  first_ready_seen_human="2026-03-30T07:01:00Z"
  first_external_completion_seen=170
  first_external_completion_seen_human="2026-03-30T07:01:10Z"
  load_test_applied=220
  load_test_applied_human="2026-03-30T07:02:00Z"
  second_ready_seen=340
  second_ready_seen_human="2026-03-30T07:04:00Z"
  load_test_deleted=460
  load_test_deleted_human="2026-03-30T07:06:00Z"
  scale_in_node_seen=640
  scale_in_node_seen_human="2026-03-30T07:09:00Z"
  inference_deleted=700
  inference_deleted_human="2026-03-30T07:10:00Z"
  all_gpu_nodes_removed=940
  all_gpu_nodes_removed_human="2026-03-30T07:14:00Z"

  render_report
  cat "${REPORT_PATH}"
  printf "%s\n" "---JSON---"
  cat "${JSON_REPORT_PATH}"
'

assert_status 0 "${COMMAND_STATUS}" "measure report helper should render a report"
assert_contains "${COMMAND_OUTPUT}" "# Dynamic GPU Serving Report" "report should include the main title"
assert_contains "${COMMAND_OUTPUT}" "- Profile: warm-1" "report should include the measurement profile"
assert_contains "${COMMAND_OUTPUT}" "- Namespace: app" "report should include the namespace"
assert_contains "${COMMAND_OUTPUT}" "- Public endpoint: http://public-edge.example.com/v1/completions" "report should include the public endpoint"
assert_contains "${COMMAND_OUTPUT}" "| First serving pod ready | 2026-03-30T07:01:00Z | 60s |" "timeline rows should include computed deltas"
assert_contains "${COMMAND_OUTPUT}" "- Cold start to first ready replica: 60s" "summary should include cold-start duration"
assert_contains "${COMMAND_OUTPUT}" "- Cold start to first successful external completion: 70s" "summary should include the first external completion timing"
assert_contains "${COMMAND_OUTPUT}" "- Full scale-down to zero GPU nodes after inference deletion: 240s" "summary should include scale-down duration"
assert_contains "${COMMAND_OUTPUT}" "## Production Summary" "report should include production summary metrics"
assert_contains "${COMMAND_OUTPUT}" "- p95 vLLM request latency during burst: 2.45s" "report should include p95 request latency"
assert_contains "${COMMAND_OUTPUT}" "- Estimated idle cost per hour for profile: \$0.526" "report should include the idle cost estimate"
assert_contains "${COMMAND_OUTPUT}" "---JSON---" "report helper should also emit the JSON artifact when requested"
assert_contains "${COMMAND_OUTPUT}" "\"generated_at\": \"2026-03-30T07:00:00Z\"" "JSON report should include generation metadata"
assert_contains "${COMMAND_OUTPUT}" "\"profile\": \"warm-1\"" "JSON report should include the measurement profile"
assert_contains "${COMMAND_OUTPUT}" "\"cold_start_ready_seconds\": 60" "JSON report should expose numeric summary durations"
assert_contains "${COMMAND_OUTPUT}" "\"cold_start_external_success_seconds\": 70" "JSON report should include the first external completion timing"
assert_contains "${COMMAND_OUTPUT}" "\"p95_vllm_request_latency_seconds\": 2.45" "JSON report should include production metrics"
assert_contains "${COMMAND_OUTPUT}" "\"estimated_idle_cost_per_hour\": 0.526" "JSON report should include cost fields"
