#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

TF_DIR="${TEST_TMPDIR}/tf"
mkdir -p "${TF_DIR}"

TERRAFORM_LOG="${TEST_TMPDIR}/terraform.log"
export TERRAFORM_LOG

# shellcheck disable=SC2016
write_stub terraform \
'#!/bin/bash' \
'set -euo pipefail' \
'printf "%s\n" "$*" >> "${TERRAFORM_LOG}"' \
'if [[ "$*" == *"output -json"* ]]; then' \
'  printf "%s\n" "{}"' \
'  exit 0' \
'fi' \
'if [[ "$*" == *"output -raw cluster_name"* ]]; then' \
'  printf "%s\n" "fallback-cluster"' \
'  exit 0' \
'fi' \
'if [[ "$*" == *"output -raw aws_region"* ]]; then' \
'  printf "%s\n" "us-west-2"' \
'  exit 0' \
'fi' \
'exit 0'

# shellcheck disable=SC2016
write_stub jq \
'#!/bin/bash' \
'set -euo pipefail' \
'case "$*" in' \
'  *"cluster_name"*) printf "%s\n" "cached-cluster" ;;' \
'  *"aws_region"*) printf "%s\n" "cached-region" ;;' \
'  *) printf "%s\n" "" ;;' \
'esac'

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" TF_DIR="${TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/terraform.sh"
  log_error() { printf "ERR:%s\n" "$*" >&2; }
  first=$(terraform_output_optional "${TF_DIR}" cluster_name)
  second=$(terraform_output_optional "${TF_DIR}" aws_region)
  printf "%s|%s\n" "${first}" "${second}"
'

assert_status 0 "${COMMAND_STATUS}" "terraform output helper should succeed with jq caching"
assert_eq "cached-cluster|cached-region" "${COMMAND_OUTPUT}" "terraform_output_optional should use cached jq values"

TERRAFORM_LOG_CONTENT=$(<"${TERRAFORM_LOG}")
assert_contains "${TERRAFORM_LOG_CONTENT}" "output -json" "terraform_output_optional should load JSON outputs"
assert_not_contains "${TERRAFORM_LOG_CONTENT}" "output -raw" "terraform_output_optional should avoid raw fallback when jq is present"

rm -f "${TEST_BIN}/jq"
: > "${TERRAFORM_LOG}"

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}" REPO_ROOT="${REPO_ROOT}" TF_DIR="${TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/terraform.sh"
  log_error() { printf "ERR:%s\n" "$*" >&2; }
  first=$(terraform_output_optional "${TF_DIR}" cluster_name)
  second=$(terraform_output_optional "${TF_DIR}" aws_region)
  printf "%s|%s\n" "${first}" "${second}"
'

assert_status 0 "${COMMAND_STATUS}" "terraform output helper should fall back to raw outputs without jq"
assert_eq "fallback-cluster|us-west-2" "${COMMAND_OUTPUT}" "terraform_output_optional should fall back to terraform output -raw"

TERRAFORM_LOG_CONTENT=$(<"${TERRAFORM_LOG}")
assert_contains "${TERRAFORM_LOG_CONTENT}" "output -raw cluster_name" "raw fallback should fetch cluster_name"
assert_contains "${TERRAFORM_LOG_CONTENT}" "output -raw aws_region" "raw fallback should fetch aws_region"

# shellcheck disable=SC2016
write_stub jq \
'#!/bin/bash' \
'set -euo pipefail' \
'printf "%s\n" ""'

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" TF_DIR="${TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/lib/terraform.sh"
  log_error() { printf "%s\n" "$*" >&2; }
  terraform_output_required "${TF_DIR}" missing_output
'

assert_status 1 "${COMMAND_STATUS}" "terraform_output_required should fail for missing outputs"
assert_contains "${COMMAND_OUTPUT}" "missing required Terraform output: missing_output" "required output failure should be explicit"
