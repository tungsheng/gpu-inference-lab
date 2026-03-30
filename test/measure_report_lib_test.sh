#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

REPORT_PATH="${TEST_TMPDIR}/reports/measurement.md"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" REPORT_PATH="${REPORT_PATH}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/measure-report.sh"

  timestamp_utc() { printf "%s\n" "2026-03-30T07:00:00Z"; }
  now_epoch() { printf "%s\n" "0"; }

  APP_NAMESPACE="app"
  DEPLOYMENT_NAME="vllm-openai"
  NODECLASS_NAME="gpu-serving"
  NODEPOOL_NAME="gpu-serving"
  POLL_INTERVAL_SECONDS=2
  REPORT_PATH=${REPORT_PATH}

  EVENT_NAMES=(start_time first_ready_seen second_ready_seen load_test_applied load_test_deleted scale_in_node_seen inference_deleted all_gpu_nodes_removed)
  TIMELINE_EVENT_LABELS=(
    "Inference manifest applied"
    "First serving pod Ready"
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
  first_ready_seen=160
  first_ready_seen_human="2026-03-30T07:01:00Z"
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
'

assert_status 0 "${COMMAND_STATUS}" "measure report helper should render a report"
assert_contains "${COMMAND_OUTPUT}" "# Dynamic GPU Serving Report" "report should include the main title"
assert_contains "${COMMAND_OUTPUT}" "- Namespace: app" "report should include the namespace"
assert_contains "${COMMAND_OUTPUT}" "| First serving pod Ready | 2026-03-30T07:01:00Z | 60s |" "timeline rows should include computed deltas"
assert_contains "${COMMAND_OUTPUT}" "- Cold start to first Ready replica: 60s" "summary should include cold-start duration"
assert_contains "${COMMAND_OUTPUT}" "- Full scale-down to zero GPU nodes after inference deletion: 240s" "summary should include scale-down duration"
