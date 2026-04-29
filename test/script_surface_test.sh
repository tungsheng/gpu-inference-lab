#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

ROOT_SCRIPTS=$(find "${REPO_ROOT}/scripts" -maxdepth 1 -type f | sed 's#.*/##' | sort)
LIB_FILES=$(find "${REPO_ROOT}/scripts/lib" -maxdepth 1 -type f | sed 's#.*/##' | sort)

assert_eq $'_common.sh\ndown\nevaluate\nexperiment\nup\nverify' "${ROOT_SCRIPTS}" "scripts/ should expose the lifecycle commands and experiment helper at the repo root"
assert_eq $'README.md\nevaluate-reports.sh\nplatform.sh' "${LIB_FILES}" "scripts/lib should contain the shared platform and report helper libraries"

assert_file_not_exists "${REPO_ROOT}/scripts/dev" "the umbrella dev CLI should be removed"
assert_file_not_exists "${REPO_ROOT}/scripts/apply-dev.sh" "the legacy apply wrapper should be removed"
assert_file_not_exists "${REPO_ROOT}/scripts/destroy-dev.sh" "the legacy destroy wrapper should be removed"
assert_file_not_exists "${REPO_ROOT}/scripts/measure-gpu-serving-path.sh" "the legacy measurement script should be removed"
