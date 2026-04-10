#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

DEPLOYMENT_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/vllm-openai.yaml")
HPA_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/hpa.yaml")
SCRIPT_CONTENT=$(cat "${REPO_ROOT}/scripts/_common.sh" "${REPO_ROOT}/scripts/up" "${REPO_ROOT}/scripts/verify" "${REPO_ROOT}/scripts/down")

assert_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: Deployment' "the default inference manifest should remain the deployment entrypoint"
assert_not_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the default inference manifest should no longer include the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the optional autoscaling manifest should define the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'name: vllm_requests_waiting' "the optional autoscaling manifest should keep the queue-depth metric target"
assert_contains "${HPA_MANIFEST_CONTENT}" 'averageValue: "2"' "the optional autoscaling manifest should preserve the target queue depth"
assert_not_contains "${SCRIPT_CONTENT}" 'platform/observability' "the baseline scripts should not reference observability manifests"
assert_not_contains "${SCRIPT_CONTENT}" 'platform/test-app' "the baseline scripts should not reference the sample app"
