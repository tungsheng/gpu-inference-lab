#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail

  source "${REPO_ROOT}/scripts/lib/measure-runtime.sh"

  ACTION_LOG=$(mktemp "${TMPDIR:-/tmp}/measure-runtime-test.XXXXXX")
  MEASUREMENT_PROFILE="zero-idle"
  WAIT_TIMEOUT_STANDARD_SECONDS=0
  GPU_SMOKE_TEST_MANIFEST="/tmp/gpu-smoke.yaml"
  GPU_LOAD_TEST_MANIFEST="/tmp/gpu-load.yaml"
  GPU_INFERENCE_MANIFEST="/tmp/gpu-inference.yaml"
  KARPENTER_WARM_NODEPOOL_MANIFEST="/tmp/gpu-warm.yaml"

  log_stage() { :; }
  delete_manifest_quiet() { printf "delete:%s\n" "$1" >> "${ACTION_LOG}"; }
  mark_measurement_state_stale() { printf "stale\n" >> "${ACTION_LOG}"; }
  delete_measurement_warm_nodepool() { printf "warm_delete\n" >> "${ACTION_LOG}"; }
  delete_measurement_profile_capacity() { printf "profile_delete:%s\n" "${MEASUREMENT_PROFILE}" >> "${ACTION_LOG}"; }
  wait_for_numeric_at_most() { printf "wait:%s\n" "$1" >> "${ACTION_LOG}"; }
  gpu_node_count() { printf "%s\n" "0"; }
  serving_state_snapshot() { :; }
  stop_wait_progress() { :; }
  log_warn() { :; }

  cleanup_existing_workloads
  cat "${ACTION_LOG}"
  rm -f "${ACTION_LOG}"
'

assert_status 0 "${COMMAND_STATUS}" "measure-runtime cleanup should succeed"
assert_contains "${COMMAND_OUTPUT}" "delete:/tmp/gpu-smoke.yaml" "cleanup should delete the smoke workload"
assert_contains "${COMMAND_OUTPUT}" "delete:/tmp/gpu-load.yaml" "cleanup should delete the load workload"
assert_contains "${COMMAND_OUTPUT}" "delete:/tmp/gpu-inference.yaml" "cleanup should delete the inference workload"
assert_contains "${COMMAND_OUTPUT}" "warm_delete" "cleanup should always remove stale warm GPU capacity before a new run"
assert_contains "${COMMAND_OUTPUT}" "profile_delete:zero-idle" "cleanup should still call profile-specific capacity cleanup when available"
assert_contains "${COMMAND_OUTPUT}" "wait:managed GPU nodes to be removed before starting a fresh run" "cleanup should still wait for managed GPU nodes to disappear"
