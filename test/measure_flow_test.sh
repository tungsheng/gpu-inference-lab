#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# shellcheck disable=SC2016
write_stub kubectl \
'#!/bin/bash' \
'set -euo pipefail' \
'exit 0'

FLOW_REPORT="${TEST_TMPDIR}/reports/flow.md"
FLOW_JSON_REPORT="${TEST_TMPDIR}/reports/flow.json"

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FLOW_REPORT="${FLOW_REPORT}" FLOW_JSON_REPORT="${FLOW_JSON_REPORT}" TEST_TMPDIR="${TEST_TMPDIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/measure-gpu-serving-path.sh"

  ACTION_LOG="${TEST_TMPDIR}/measure-flow.log"
  : > "${ACTION_LOG}"
  EVENT_TS=100

  timestamp_utc() { printf "%s\n" "2026-03-30T09:00:00Z"; }
  verify_cluster_connectivity() { return 0; }
  resource_exists() { return 0; }
  namespace_exists() { return 0; }
  crd_exists() { return 0; }

  record_event() {
    local event_name=$1
    printf -v "${event_name}" "%s" "${EVENT_TS}"
    printf -v "${event_name}_human" "t%s" "${EVENT_TS}"
    printf "event:%s\n" "${event_name}" >> "${ACTION_LOG}"
    EVENT_TS=$((EVENT_TS + 10))
  }

  ensure_namespace() {
    printf "ensure_namespace:%s\n" "$1" >> "${ACTION_LOG}"
  }

  apply_manifest_quiet() {
    printf "apply:%s\n" "$1" >> "${ACTION_LOG}"
  }

  delete_manifest_quiet() {
    printf "delete:%s\n" "$1" >> "${ACTION_LOG}"
  }

  wait_for_value() {
    printf "wait_value:%s\n" "$1" >> "${ACTION_LOG}"
    return 0
  }

  wait_for_numeric_at_least() {
    printf "wait_at_least:%s:%s\n" "$1" "$3" >> "${ACTION_LOG}"
    return 0
  }

  wait_for_numeric_at_most() {
    printf "wait_at_most:%s:%s\n" "$1" "$3" >> "${ACTION_LOG}"
    return 0
  }

  wait_for_gpu_allocatable() {
    printf "wait_gpu:%s\n" "$1" >> "${ACTION_LOG}"
    return 0
  }

  find_gpu_node_name() {
    if [[ -n "${1:-}" ]]; then
      printf "%s\n" "gpu-b"
    else
      printf "%s\n" "gpu-a"
    fi
  }

  inference_edge_url() {
    printf "%s\n" "http://public-edge.example.com/v1/completions"
  }

  main --report "${FLOW_REPORT}" --json-report "${FLOW_JSON_REPORT}" --no-spinner

  cat "${ACTION_LOG}"
  printf "%s\n" "---REPORT---"
  cat "${FLOW_REPORT}"
  printf "%s\n" "---JSON---"
  cat "${FLOW_JSON_REPORT}"
'

assert_status 0 "${COMMAND_STATUS}" "measure flow should complete successfully with stubbed cluster interactions"
assert_contains "${COMMAND_OUTPUT}" "delete:${REPO_ROOT}/platform/tests/gpu-test.yaml
delete:${REPO_ROOT}/platform/tests/gpu-load-test.yaml
delete:${REPO_ROOT}/platform/inference/vllm-openai.yaml
wait_at_most:GPU nodes to scale back to zero before starting a fresh run:0
ensure_namespace:app
apply:${REPO_ROOT}/platform/inference/service.yaml
apply:${REPO_ROOT}/platform/inference/ingress.yaml
event:start_time
wait_value:the inference ingress hostname to appear
event:edge_hostname_seen" "measure flow should begin with cleanup, namespace setup, edge installation, and edge hostname tracking"
assert_contains "${COMMAND_OUTPUT}" "apply:${REPO_ROOT}/platform/inference/vllm-openai.yaml
wait_value:the first serving pod to be created
event:first_pod_seen
wait_at_least:the first NodeClaim:1
event:first_nodeclaim_seen" "cold-start flow should apply the inference workload and record early milestones"
assert_contains "${COMMAND_OUTPUT}" "wait_at_least:the first Ready serving replica:1
event:first_ready_seen
wait_value:the first successful external completion
event:first_external_completion_seen" "cold-start flow should also record the first external completion through the public edge"
assert_contains "${COMMAND_OUTPUT}" "apply:${REPO_ROOT}/platform/tests/gpu-load-test.yaml
event:load_test_applied
wait_at_least:the HPA desired replica count to reach 2:2
event:hpa_scale_out_seen" "scale-out flow should apply load and record HPA expansion"
assert_contains "${COMMAND_OUTPUT}" "delete:${REPO_ROOT}/platform/tests/gpu-load-test.yaml
event:load_test_deleted
wait_at_most:the deployment to settle back to one Ready replica:1
event:scale_in_ready_seen
wait_at_most:the extra GPU node to terminate:1
event:scale_in_node_seen
delete:${REPO_ROOT}/platform/inference/vllm-openai.yaml
event:inference_deleted
wait_at_most:all GPU nodes to scale back to zero:0
event:all_gpu_nodes_removed" "scale-down flow should remove load and inference manifests in order"
assert_contains "${COMMAND_OUTPUT}" "---REPORT---" "measure flow should generate a report"
assert_contains "${COMMAND_OUTPUT}" "# Dynamic GPU Serving Report" "generated report should include the title"
assert_contains "${COMMAND_OUTPUT}" "- Public endpoint: http://public-edge.example.com/v1/completions" "generated report should include the public inference endpoint"
assert_contains "${COMMAND_OUTPUT}" "- Cold start to first Ready replica: 60s" "generated report should summarize cold-start timing"
assert_contains "${COMMAND_OUTPUT}" "- Cold start to first successful external completion: 70s" "generated report should summarize the first public-edge completion"
assert_contains "${COMMAND_OUTPUT}" "- Load-triggered scale-out to two Ready replicas: 40s" "generated report should summarize scale-out timing"
assert_contains "${COMMAND_OUTPUT}" "---JSON---" "measure flow should generate a JSON report when requested"
assert_contains "${COMMAND_OUTPUT}" "\"load_test_applied\"" "JSON report should include timeline event names"
assert_contains "${COMMAND_OUTPUT}" "\"public_endpoint\": \"http://public-edge.example.com/v1/completions\"" "JSON report should include the public inference endpoint"
assert_contains "${COMMAND_OUTPUT}" "\"cold_start_external_success_seconds\": 70" "JSON report should expose the first successful external completion timing"
assert_contains "${COMMAND_OUTPUT}" "\"scale_out_ready_seconds\": 40" "JSON report should expose numeric scale-out timing"
