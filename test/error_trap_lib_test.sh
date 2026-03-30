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
  source "${REPO_ROOT}/scripts/lib/error-trap.sh"

  SCRIPT_NAME="trap-test"
  current_step="install platform dependencies"
  print_diag() { printf "%s\n" "diag-called"; }
  should_collect() { return 0; }
  STEP_ERROR_DIAGNOSTICS_COMMAND="print_diag"
  STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND="should_collect"
  handle_step_error 7 42
'

assert_status 7 "${COMMAND_STATUS}" "step error trap should exit with the original failure status"
assert_contains "${COMMAND_OUTPUT}" 'failed at line 42 during step: install platform dependencies' "step error trap should report the failing step"
assert_contains "${COMMAND_OUTPUT}" 'diag-called' "step error trap should run diagnostics when the guard allows it"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/error-trap.sh"

  SCRIPT_NAME="trap-test"
  current_step="destroy platform resources"
  print_diag() { printf "%s\n" "diag-called"; }
  should_collect() { return 1; }
  STEP_ERROR_DIAGNOSTICS_COMMAND="print_diag"
  STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND="should_collect"
  handle_step_error 9 88
'

assert_status 9 "${COMMAND_STATUS}" "step error trap should preserve the failure status when diagnostics are skipped"
assert_contains "${COMMAND_OUTPUT}" 'failed at line 88 during step: destroy platform resources' "step error trap should still report the failing line when diagnostics are skipped"
assert_not_contains "${COMMAND_OUTPUT}" 'diag-called' "step error trap should skip diagnostics when the guard blocks them"
