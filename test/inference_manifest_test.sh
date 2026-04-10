#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

DEPLOYMENT_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/vllm-openai.yaml")
HPA_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/hpa.yaml")
LOAD_TEST_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/tests/gpu-load-test.yaml")
SCRIPT_CONTENT=$(cat "${REPO_ROOT}/scripts/_common.sh" "${REPO_ROOT}/scripts/up" "${REPO_ROOT}/scripts/verify" "${REPO_ROOT}/scripts/down" "${REPO_ROOT}/scripts/evaluate")

assert_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: Deployment' "the default inference manifest should remain the deployment entrypoint"
assert_not_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the default inference manifest should no longer include the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the optional autoscaling manifest should define the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'name: vllm_requests_waiting' "the optional autoscaling manifest should keep the queue-depth metric target"
assert_contains "${HPA_MANIFEST_CONTENT}" 'averageValue: "2"' "the optional autoscaling manifest should preserve the target queue depth"
assert_contains "${SCRIPT_CONTENT}" 'platform/observability' "the platform lifecycle should now reference observability manifests"
assert_contains "${SCRIPT_CONTENT}" 'platform/tests/gpu-load-test.yaml' "the evaluation flow should reference the load test manifest"
assert_contains "${SCRIPT_CONTENT}" 'platform/karpenter/nodepool-gpu-warm.yaml' "the evaluation flow should reference the warm capacity profile"
assert_not_contains "${SCRIPT_CONTENT}" 'platform/test-app' "the baseline scripts should not reference the sample app"
assert_not_contains "${LOAD_TEST_MANIFEST_CONTENT}" 'CPU-based HPA scale-out' "the load test should no longer describe the old CPU-based scale-out path"
