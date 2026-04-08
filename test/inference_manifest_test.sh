#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/vllm-openai.yaml")

assert_contains "${MANIFEST_CONTENT}" 'name: vllm_requests_waiting' "inference HPA should scale on the Prometheus-backed queue metric"
assert_contains "${MANIFEST_CONTENT}" 'averageValue: "2"' "inference HPA should target an average queue depth per pod"
assert_not_contains "${MANIFEST_CONTENT}" 'name: cpu' "inference HPA should no longer scale on CPU"
assert_not_contains "${MANIFEST_CONTENT}" 'averageUtilization:' "inference HPA should no longer use CPU utilization targets"
