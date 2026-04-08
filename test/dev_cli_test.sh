#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev help should succeed"
assert_contains "${COMMAND_OUTPUT}" "doctor" "scripts/dev help should list doctor"
assert_contains "${COMMAND_OUTPUT}" "status" "scripts/dev help should list status"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" measure --help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev measure --help should succeed"
assert_contains "${COMMAND_OUTPUT}" "--report" "measure help should describe report flag"
assert_contains "${COMMAND_OUTPUT}" "--json-report" "measure help should describe JSON report flag"
assert_contains "${COMMAND_OUTPUT}" "--profile" "measure help should describe capacity profiles"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" up --help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev up --help should succeed"
assert_contains "${COMMAND_OUTPUT}" "terraform apply args" "apply help should mention terraform args"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" down --help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev down --help should succeed"
assert_contains "${COMMAND_OUTPUT}" "terraform destroy args" "destroy help should mention terraform args"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" doctor --help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev doctor --help should succeed"
assert_contains "${COMMAND_OUTPUT}" "--json" "doctor help should mention JSON output"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" status --help
assert_status 0 "${COMMAND_STATUS}" "scripts/dev status --help should succeed"
assert_contains "${COMMAND_OUTPUT}" "--verbose" "status help should mention verbose output"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/dev" nope
assert_status 1 "${COMMAND_STATUS}" "unknown scripts/dev command should fail"
assert_contains "${COMMAND_OUTPUT}" "unknown command: nope" "unknown command error should be clear"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/measure-gpu-serving-path.sh" --bogus
assert_status 1 "${COMMAND_STATUS}" "unknown measurement option should fail"
assert_contains "${COMMAND_OUTPUT}" "unknown option: --bogus" "unknown measurement option should be surfaced"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/measure-gpu-serving-path.sh" --json-report
assert_status 1 "${COMMAND_STATUS}" "measurement JSON report flag should require a value"
assert_contains "${COMMAND_OUTPUT}" "--json-report requires a value" "measurement JSON report flag should fail clearly without a path"

link_system_command dirname
run_and_capture env PATH="${TEST_BIN}" /bin/bash "${REPO_ROOT}/scripts/dev" doctor
assert_status 1 "${COMMAND_STATUS}" "doctor should fail when core tools are missing"
assert_contains "${COMMAND_OUTPUT}" "terraform: missing from PATH" "doctor should report missing terraform"
