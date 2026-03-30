#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

FAKE_TF_DIR="${TEST_TMPDIR}/infra/env/dev"
mkdir -p "${FAKE_TF_DIR}"

# shellcheck disable=SC2016
write_stub terraform \
'#!/bin/bash' \
'set -euo pipefail' \
'exit 0'

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FAKE_TF_DIR="${FAKE_TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/terraform-wrapper.sh"

  SCRIPT_NAME="terraform-wrapper-test"
  validate_terraform_wrapper_prereqs "${FAKE_TF_DIR}"
  terraform_wrapper_help_requested --help && printf "%s\n" "help=true"
  reject_unsupported_terraform_wrapper_args apply "${FAKE_TF_DIR}" -auto-approve
  printf "%s\n" "apply-ok"
  reject_unsupported_terraform_wrapper_args destroy "${FAKE_TF_DIR}" -auto-approve
  printf "%s\n" "destroy-ok"
'

assert_status 0 "${COMMAND_STATUS}" "terraform wrapper helpers should allow supported full apply and destroy args"
assert_contains "${COMMAND_OUTPUT}" 'help=true' "terraform wrapper helper should recognize help flags"
assert_contains "${COMMAND_OUTPUT}" 'apply-ok' "terraform wrapper helper should allow regular apply args"
assert_contains "${COMMAND_OUTPUT}" 'destroy-ok' "terraform wrapper helper should allow regular destroy args"

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FAKE_TF_DIR="${FAKE_TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/terraform-wrapper.sh"

  SCRIPT_NAME="terraform-wrapper-test"
  reject_unsupported_terraform_wrapper_args apply "${FAKE_TF_DIR}" -target=module.eks
'

assert_status 1 "${COMMAND_STATUS}" "terraform wrapper helper should reject targeted apply usage"
assert_contains "${COMMAND_OUTPUT}" 'only supports full environment apply' "terraform wrapper helper should explain rejected apply args"

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FAKE_TF_DIR="${FAKE_TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/terraform-wrapper.sh"

  SCRIPT_NAME="terraform-wrapper-test"
  reject_unsupported_terraform_wrapper_args destroy "${FAKE_TF_DIR}" -target=module.eks
'

assert_status 1 "${COMMAND_STATUS}" "terraform wrapper helper should reject targeted destroy usage"
assert_contains "${COMMAND_OUTPUT}" 'only supports full environment teardown' "terraform wrapper helper should explain rejected destroy args"
