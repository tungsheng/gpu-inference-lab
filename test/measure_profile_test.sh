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

FLOW_REPORT="${TEST_TMPDIR}/reports/warm-profile.md"
FLOW_JSON_REPORT="${TEST_TMPDIR}/reports/warm-profile.json"

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FLOW_REPORT="${FLOW_REPORT}" FLOW_JSON_REPORT="${FLOW_JSON_REPORT}" TEST_TMPDIR="${TEST_TMPDIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/measure-gpu-serving-path.sh"

  ACTION_LOG="${TEST_TMPDIR}/measure-profile.log"
  : > "${ACTION_LOG}"
  EVENT_TS=100

  timestamp_utc() { printf "%s\n" "2026-03-31T09:00:00Z"; }
  verify_cluster_connectivity() { return 0; }
  resource_exists() { return 0; }
  resource_condition_is_status() { return 0; }
  namespace_exists() { return 0; }
  crd_exists() { return 0; }

  record_event() {
    local event_name=$1
    printf -v "${event_name}" "%s" "${EVENT_TS}"
    printf -v "${event_name}_human" "t%s" "${EVENT_TS}"
    printf "event:%s\n" "${event_name}" >> "${ACTION_LOG}"
    EVENT_TS=$((EVENT_TS + 10))
  }

  ensure_namespace() { :; }
  apply_manifest_quiet() {
    local manifest_path=$1
    printf "apply:%s\n" "${manifest_path}" >> "${ACTION_LOG}"
    if grep -Fq "capacity-profile: warm-1" "${manifest_path}"; then
      printf "warm_apply_name:%s\n" "$(sed -n "s/^  name: //p" "${manifest_path}" | head -n 1)" >> "${ACTION_LOG}"
      printf "warm_apply_nodeclass:%s\n" "$(sed -n "s/^        name: //p" "${manifest_path}" | head -n 1)" >> "${ACTION_LOG}"
    fi
  }
  delete_manifest_quiet() {
    local manifest_path=$1
    printf "delete:%s\n" "${manifest_path}" >> "${ACTION_LOG}"
    if grep -Fq "capacity-profile: warm-1" "${manifest_path}"; then
      printf "warm_delete_name:%s\n" "$(sed -n "s/^  name: //p" "${manifest_path}" | head -n 1)" >> "${ACTION_LOG}"
      printf "warm_delete_nodeclass:%s\n" "$(sed -n "s/^        name: //p" "${manifest_path}" | head -n 1)" >> "${ACTION_LOG}"
    fi
  }
  wait_for_value() { return 0; }
  wait_for_numeric_at_least() { return 0; }
  wait_for_numeric_at_most() { return 0; }
  wait_for_gpu_allocatable() { return 0; }
  wait_for_status_condition() { return 0; }
  find_gpu_node_name() { printf "%s\n" "gpu-a"; }
  node_instance_type() { printf "%s\n" "g4dn.xlarge"; }
  first_gpu_node_allocatable() { printf "%s\n" "1"; }
  nodeclaim_count() { printf "%s\n" "1"; }
  gpu_node_count() { printf "%s\n" "1"; }
  event_timestamp() { local event_name=$1; printf "%s\n" "${!event_name:-}"; }
  inference_edge_url() { printf "%s\n" "http://warm-edge.example.com/v1/completions"; }
  collect_measurement_production_summary() {
    ESTIMATED_IDLE_COST_PER_HOUR="0.526"
    ESTIMATED_BURST_COST="0.071000"
  }
  push_measurement_summary_metrics() { :; }
  stop_measurement_port_forwards() { :; }

  main --profile warm-1 --nodepool custom-serving --nodeclass custom-class --report "${FLOW_REPORT}" --json-report "${FLOW_JSON_REPORT}" --no-spinner

  printf "profile:%s|%s\n" "${MEASUREMENT_PROFILE}" "${MEASUREMENT_NODEPOOL_SELECTOR}" >> "${ACTION_LOG}"
  cat "${ACTION_LOG}"
  printf "%s\n" "---JSON---"
  cat "${FLOW_JSON_REPORT}"
'

assert_status 0 "${COMMAND_STATUS}" "warm profile flow should complete successfully with stubbed interactions"
assert_contains "${COMMAND_OUTPUT}" "profile:warm-1|karpenter.sh/nodepool in (custom-serving,gpu-warm-1)" "warm profile should widen the nodeclaim selector to both the selected GPU nodepool and the warm GPU nodepool"
assert_contains "${COMMAND_OUTPUT}" "warm_apply_name:gpu-warm-1" "warm profile should render the configured warm GPU NodePool name"
assert_contains "${COMMAND_OUTPUT}" "warm_apply_nodeclass:custom-class" "warm profile should render the selected NodeClass into the warm GPU NodePool"
assert_contains "${COMMAND_OUTPUT}" "warm_delete_name:gpu-warm-1" "warm profile cleanup should target the configured warm GPU NodePool name"
assert_contains "${COMMAND_OUTPUT}" "warm_delete_nodeclass:custom-class" "warm profile cleanup should render the selected NodeClass into the warm GPU NodePool"
assert_contains "${COMMAND_OUTPUT}" "\"profile\": \"warm-1\"" "warm profile JSON report should preserve the selected capacity profile"
assert_contains "${COMMAND_OUTPUT}" "\"estimated_idle_cost_per_hour\": 0.526" "warm profile JSON report should include the warm idle cost estimate"
