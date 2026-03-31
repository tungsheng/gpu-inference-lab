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
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/measure-wait.sh"

  DISABLE_SPINNER=1
  POLL_INTERVAL_SECONDS=0
  PROGRESS_LOG_INTERVAL_SECONDS=1
  STATE_REFRESH_INTERVAL_SECONDS=1
  API_HEALTHCHECK_INTERVAL_SECONDS=10
  SPINNER_INTERVAL_TENTHS=1
  initialize_measurement_context
  COUNTER_FILE=$(mktemp "${TMPDIR:-/tmp}/measure-wait-counter.XXXXXX")
  CLOCK_FILE=$(mktemp "${TMPDIR:-/tmp}/measure-wait-clock.XXXXXX")
  printf "%s\n" "0" > "${COUNTER_FILE}"
  cat > "${CLOCK_FILE}" <<EOF
100
100
100
101
101
EOF
  NOW_FALLBACK=101

  now_epoch() {
    local value

    value=$(head -n 1 "${CLOCK_FILE}" 2>/dev/null || true)
    if [[ -n "${value}" ]]; then
      tail -n +2 "${CLOCK_FILE}" > "${CLOCK_FILE}.next"
      mv -f "${CLOCK_FILE}.next" "${CLOCK_FILE}"
    else
      value=${NOW_FALLBACK}
    fi

    printf "%s\n" "${value}"
  }

  verify_cluster_connectivity() { return 0; }
  value_command() {
    local current_value
    current_value=$(<"${COUNTER_FILE}")
    current_value=$((current_value + 1))
    printf "%s\n" "${current_value}" > "${COUNTER_FILE}"
    printf "%s\n" "${current_value}"
  }
  snapshot_command() { printf "count=%s\n" "$(<"${COUNTER_FILE}")"; }

  result=$(wait_for_numeric_at_least "counter reaches two" 2 2 value_command snapshot_command)
  printf "result=%s\n" "${result}"
'

assert_status 0 "${COMMAND_STATUS}" "wait helper should succeed when the target is reached"
assert_contains "${COMMAND_OUTPUT}" "counter reaches two |" "wait helper should log the success description"
assert_contains "${COMMAND_OUTPUT}" "count=2" "wait helper should log the final observed state"
assert_contains "${COMMAND_OUTPUT}" "result=2" "wait helper should return the normalized value"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/measure-wait.sh"

  DISABLE_SPINNER=1
  POLL_INTERVAL_SECONDS=0
  PROGRESS_LOG_INTERVAL_SECONDS=1
  STATE_REFRESH_INTERVAL_SECONDS=1
  API_HEALTHCHECK_INTERVAL_SECONDS=10
  SPINNER_INTERVAL_TENTHS=1
  initialize_measurement_context
  CLOCK_FILE=$(mktemp "${TMPDIR:-/tmp}/measure-wait-clock.XXXXXX")
  cat > "${CLOCK_FILE}" <<EOF
200
200
200
201
201
EOF
  NOW_FALLBACK=202

  now_epoch() {
    local value

    value=$(head -n 1 "${CLOCK_FILE}" 2>/dev/null || true)
    if [[ -n "${value}" ]]; then
      tail -n +2 "${CLOCK_FILE}" > "${CLOCK_FILE}.next"
      mv -f "${CLOCK_FILE}.next" "${CLOCK_FILE}"
    else
      value=${NOW_FALLBACK}
    fi

    printf "%s\n" "${value}"
  }

  verify_cluster_connectivity() { return 0; }
  value_command() { printf "%s\n" "0"; }
  snapshot_command() { printf "%s\n" "count=0"; }
  timeout_command() { printf "%s\n" "timeout-context"; }

  wait_for_condition "counter reaches one" 1 "at-least" 1 value_command snapshot_command "" "" timeout_command
'

assert_status 1 "${COMMAND_STATUS}" "wait helper should fail on timeout"
assert_contains "${COMMAND_OUTPUT}" "counter reaches one timed out after 00m01s" "timeout should be reported clearly"
assert_contains "${COMMAND_OUTPUT}" "timeout-context" "timeout diagnostics should be invoked"
