#!/usr/bin/env bash

TEST_HELPERS_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034
REPO_ROOT=$(cd -- "${TEST_HELPERS_DIR}/../.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1
  local actual=$2
  local message=${3:-"expected '${expected}' but got '${actual}'"}

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${message}"
  fi
}

assert_contains() {
  local haystack=$1
  local needle=$2
  local message=${3:-"expected output to contain '${needle}'"}

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${message}"
  fi
}

assert_not_contains() {
  local haystack=$1
  local needle=$2
  local message=${3:-"expected output not to contain '${needle}'"}

  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "${message}"
  fi
}

assert_status() {
  local expected=$1
  local actual=$2
  local message=${3:-"expected status ${expected} but got ${actual}"}

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${message}"
  fi
}

setup_test_tmpdir() {
  TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/gpu-lab-test.XXXXXX")
  TEST_BIN="${TEST_TMPDIR}/bin"
  mkdir -p "${TEST_BIN}"
  export TEST_TMPDIR TEST_BIN
}

teardown_test_tmpdir() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "${TEST_TMPDIR}" ]]; then
    rm -rf "${TEST_TMPDIR}"
  fi
}

write_stub() {
  local name=$1
  shift
  local stub_path="${TEST_BIN}/${name}"

  printf '%s\n' "$@" > "${stub_path}"
  chmod +x "${stub_path}"
}

link_system_command() {
  local command_name=$1
  local source_path

  source_path=$(command -v "${command_name}")
  ln -sf "${source_path}" "${TEST_BIN}/${command_name}"
}

run_and_capture() {
  local status

  set +e
  COMMAND_OUTPUT=$("$@" 2>&1)
  status=$?
  set -e

  COMMAND_STATUS=${status}
  export COMMAND_OUTPUT COMMAND_STATUS
}
