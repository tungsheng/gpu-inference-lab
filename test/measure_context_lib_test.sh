#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/measure-context.sh"

  LAST_PROGRESS_LOG_AT=9
  WAIT_PROGRESS_FILE="/tmp/progress"
  WAIT_SPINNER_PID="77"
  PROMETHEUS_PORT_FORWARD_PID="88"
  PROMETHEUS_LOCAL_PORT="19090"
  first_gpu_node_name="gpu-a"
  second_gpu_node_name="gpu-b"
  MEASUREMENT_STATE_CACHE_KEY="55"
  MEASUREMENT_STATE_REFRESHED_AT="55"
  STATE_GPU_NODE_COUNT="2"
  STATE_LOAD_TEST_EXISTS="1"
  MEASUREMENT_PROFILE="warm-1"
  PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS="1.2"

  initialize_measurement_context
  printf "wait=%s|%s|%s\n" "${LAST_PROGRESS_LOG_AT}" "${WAIT_PROGRESS_FILE}" "${WAIT_SPINNER_PID}"
  printf "port_forward=%s|%s\n" "${PROMETHEUS_PORT_FORWARD_PID}" "${PROMETHEUS_LOCAL_PORT}"
  printf "nodes=%s|%s\n" "${first_gpu_node_name}" "${second_gpu_node_name}"
  printf "cache=%s|%s\n" "$(measurement_state_cache_key)" "${MEASUREMENT_STATE_REFRESHED_AT}"
  printf "state=%s|%s\n" "${STATE_GPU_NODE_COUNT}" "${STATE_LOAD_TEST_EXISTS}"
  printf "profile=%s\n" "${MEASUREMENT_PROFILE}"
  printf "production=%s\n" "${PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS}"
  printf "timeline=%s|%s\n" "${EVENT_NAMES[0]}" "${TIMELINE_EVENT_LABELS[0]}"

  set_measurement_state_cache_key "88"
  printf "cache_set=%s\n" "$(measurement_state_cache_key)"
  clear_measurement_state_cache_key
  printf "cache_clear=%s\n" "$(measurement_state_cache_key)"
'

assert_status 0 "${COMMAND_STATUS}" "measure-context helpers should initialize clean shared state"
assert_contains "${COMMAND_OUTPUT}" "wait=0||" "initialize_measurement_context should reset wait progress state"
assert_contains "${COMMAND_OUTPUT}" "port_forward=|" "initialize_measurement_context should clear port-forward state"
assert_contains "${COMMAND_OUTPUT}" "nodes=|" "initialize_measurement_context should clear tracked GPU node names"
assert_contains "${COMMAND_OUTPUT}" "cache=|" "initialize_measurement_context should clear cached snapshot metadata"
assert_contains "${COMMAND_OUTPUT}" "state=0|0" "initialize_measurement_context should restore cached state defaults"
assert_contains "${COMMAND_OUTPUT}" "profile=zero-idle" "initialize_measurement_context should restore the default measurement profile"
assert_contains "${COMMAND_OUTPUT}" "production=" "initialize_measurement_context should clear production summary values"
assert_contains "${COMMAND_OUTPUT}" "timeline=start_time|Measurement start" "measure-context should provide the default timeline metadata"
assert_contains "${COMMAND_OUTPUT}" "cache_set=88" "set_measurement_state_cache_key should update the cache key"
assert_contains "${COMMAND_OUTPUT}" "cache_clear=" "clear_measurement_state_cache_key should empty the cache key"
