#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

DEPLOYMENT_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/vllm-openai.yaml")
HPA_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/hpa.yaml")
LOAD_TEST_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/tests/gpu-load-test.yaml")
WARM_PLACEHOLDER_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml")
ONDEMAND_NODEPOOL_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml")
SPOT_NODEPOOL_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml")
SCRIPT_CONTENT=$(cat "${REPO_ROOT}/scripts/_common.sh" "${REPO_ROOT}/scripts/up" "${REPO_ROOT}/scripts/verify" "${REPO_ROOT}/scripts/down" "${REPO_ROOT}/scripts/evaluate")

assert_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: Deployment' "the default inference manifest should remain the deployment entrypoint"
assert_not_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the default inference manifest should no longer include the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the optional autoscaling manifest should define the HPA"
assert_contains "${HPA_MANIFEST_CONTENT}" 'name: vllm_requests_running' "the optional autoscaling manifest should use the running-request metric target"
assert_contains "${HPA_MANIFEST_CONTENT}" 'averageValue: "128"' "the optional autoscaling manifest should scale out once a single replica is carrying sustained high concurrency"
assert_contains "$(cat "${REPO_ROOT}/platform/observability/prometheus-adapter-values.yaml")" 'vllm:num_requests_running' "the adapter should expose the running-request metric the HPA depends on"
assert_contains "$(cat "${REPO_ROOT}/platform/observability/prometheus-adapter-values.yaml")" 'max_over_time' "the adapter should keep a short running-request window so the HPA can see transient saturation"
assert_contains "${SCRIPT_CONTENT}" 'platform/observability' "the platform lifecycle should now reference observability manifests"
assert_contains "${SCRIPT_CONTENT}" 'platform/tests/gpu-load-test.yaml' "the evaluation flow should reference the load test manifest"
assert_contains "${SCRIPT_CONTENT}" 'platform/tests/gpu-warm-placeholder.yaml' "the evaluation flow should reference the warm placeholder workload"
assert_contains "${SCRIPT_CONTENT}" 'platform/karpenter/nodepool-gpu-serving-ondemand.yaml' "the platform lifecycle should install the on-demand serving NodePool"
assert_contains "${SCRIPT_CONTENT}" 'platform/karpenter/nodepool-gpu-serving-spot.yaml' "the platform lifecycle should install the spot serving NodePool"
assert_not_contains "${SCRIPT_CONTENT}" 'platform/test-app' "the baseline scripts should not reference the sample app"
assert_not_contains "${LOAD_TEST_MANIFEST_CONTENT}" 'CPU-based HPA scale-out' "the load test should no longer describe the old CPU-based scale-out path"
assert_contains "${LOAD_TEST_MANIFEST_CONTENT}" 'executor: "ramping-arrival-rate"' "the load test should use an arrival-rate executor so latency does not suppress the generated backlog"
assert_contains "${WARM_PLACEHOLDER_MANIFEST_CONTENT}" 'nodeSelector:' "the warm placeholder should target GPU-labelled nodes"
assert_contains "${WARM_PLACEHOLDER_MANIFEST_CONTENT}" 'serving: vllm' "the warm placeholder should pin the warm node to the same serving pool as vLLM"
assert_contains "${WARM_PLACEHOLDER_MANIFEST_CONTENT}" 'karpenter.sh/capacity-type: on-demand' "the warm placeholder should keep the baseline on on-demand capacity"
assert_not_contains "${WARM_PLACEHOLDER_MANIFEST_CONTENT}" 'nvidia.com/gpu' "the warm placeholder should leave the GPU free for the real inference pod"
assert_contains "${ONDEMAND_NODEPOOL_MANIFEST_CONTENT}" 'name: gpu-serving-ondemand' "the on-demand serving NodePool should use the new explicit name"
assert_contains "${ONDEMAND_NODEPOOL_MANIFEST_CONTENT}" 'values:' "the on-demand serving NodePool should declare explicit scheduling requirements"
assert_contains "${ONDEMAND_NODEPOOL_MANIFEST_CONTENT}" 'on-demand' "the on-demand serving NodePool should pin capacity type to on-demand"
assert_contains "${SPOT_NODEPOOL_MANIFEST_CONTENT}" 'name: gpu-serving-spot' "the spot serving NodePool should use the new explicit name"
assert_contains "${SPOT_NODEPOOL_MANIFEST_CONTENT}" 'weight: 50' "the spot serving NodePool should be preferred for new provisioning"
assert_contains "${SPOT_NODEPOOL_MANIFEST_CONTENT}" 'spot' "the spot serving NodePool should pin capacity type to spot"
