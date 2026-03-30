#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

KUBECTL_LOG="${TEST_TMPDIR}/kubectl.log"
export KUBECTL_LOG

# shellcheck disable=SC2016
write_stub kubectl \
'#!/bin/bash' \
'set -euo pipefail' \
'printf "%s\n" "$*" >> "${KUBECTL_LOG}"' \
'case "$*" in' \
'  "get pods -o name -n app -l app=demo")' \
'    printf "%s\n" "pod/demo-1" "pod/demo-2"' \
'    ;;' \
'  "get nodeclaims -o name -A")' \
'    printf "%s\n" "nodeclaim/one" "nodeclaim/two" "nodeclaim/three"' \
'    ;;' \
'  "get namespace existing")' \
'    exit 0' \
'    ;;' \
'  "get namespace missing")' \
'    exit 1' \
'    ;;' \
'  "create namespace missing")' \
'    printf "%s\n" "namespace/missing created"' \
'    ;;' \
'esac'

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/kube.sh"
  log() { printf "LOG:%s\n" "$*"; }
  count_namespaced=$(kubectl_name_count pods app "app=demo")
  count_all=$(kubectl_name_count nodeclaims "" "" 1)
  ensure_namespace existing
  ensure_namespace missing
  printf "namespaced=%s all=%s\n" "${count_namespaced}" "${count_all}"
'

assert_status 0 "${COMMAND_STATUS}" "kube helper test command should succeed"
assert_contains "${COMMAND_OUTPUT}" "namespaced=2 all=3" "kubectl_name_count should count namespaced and all-namespace resources"
assert_contains "${COMMAND_OUTPUT}" "LOG:creating namespace: missing" "ensure_namespace should log namespace creation"

KUBECTL_LOG_CONTENT=$(<"${KUBECTL_LOG}")
assert_contains "${KUBECTL_LOG_CONTENT}" "get pods -o name -n app -l app=demo" "kubectl_name_count should pass namespace and selector"
assert_contains "${KUBECTL_LOG_CONTENT}" "get nodeclaims -o name -A" "kubectl_name_count should support all-namespaces"
assert_contains "${KUBECTL_LOG_CONTENT}" "create namespace missing" "ensure_namespace should create only missing namespaces"
assert_not_contains "${KUBECTL_LOG_CONTENT}" "create namespace existing" "ensure_namespace should not recreate existing namespaces"
