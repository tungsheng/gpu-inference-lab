#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail

  APP_NAMESPACE="app"
  NODEPOOL_NAME="gpu-serving"
  KARPENTER_WARM_NODEPOOL_NAME="gpu-warm-1"
  ACTION_LOG=$(mktemp "${TMPDIR:-/tmp}/measure-production-test.XXXXXX")

  source "${REPO_ROOT}/scripts/lib/measure-production.sh"

  measurement_lookback_seconds() { printf "%s\n" "600s"; }
  estimate_measurement_costs() { :; }
  prometheus_query_scalar_with_fallback() {
    printf "fallback:%s\n" "$1" >> "${ACTION_LOG}"
    printf "%s\n" "1"
  }
  prometheus_query_scalar() {
    printf "direct:%s\n" "$1" >> "${ACTION_LOG}"
    printf "%s\n" "1"
  }

  configure_measurement_profile zero-idle
  collect_measurement_production_summary
  configure_measurement_profile warm-1
  collect_measurement_production_summary

  cat "${ACTION_LOG}"
  rm -f "${ACTION_LOG}"
'

assert_status 0 "${COMMAND_STATUS}" "measure-production helpers should build scoped Prometheus queries"
assert_contains "${COMMAND_OUTPUT}" 'direct:max_over_time(((sum(karpenter_nodeclaims_created_total{nodepool=~"^gpu-serving$"}) - sum(karpenter_nodeclaims_terminated_total{nodepool=~"^gpu-serving$"})))[600s:1m])' "zero-idle production summary should scope NodeClaims to the dynamic GPU nodepool"
assert_contains "${COMMAND_OUTPUT}" 'direct:max_over_time(((sum(karpenter_nodeclaims_created_total{nodepool=~"^(gpu-serving|gpu-warm-1)$"}) - sum(karpenter_nodeclaims_terminated_total{nodepool=~"^(gpu-serving|gpu-warm-1)$"})))[600s:1m])' "warm production summary should scope NodeClaims to both GPU-serving nodepools"
