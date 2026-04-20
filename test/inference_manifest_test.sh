#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

DEPLOYMENT_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/vllm-openai.yaml")
RUNNING_HPA_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/hpa.yaml")
ACTIVE_PRESSURE_HPA_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/inference/hpa-active-pressure.yaml")
ADAPTER_VALUES_CONTENT=$(cat "${REPO_ROOT}/platform/observability/prometheus-adapter-values.yaml")
DASHBOARD_CONTENT=$(cat "${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml")
SERVING_DASHBOARD_CONTENT=$(cat "${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml")
LOAD_TEST_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/tests/gpu-load-test.yaml")
WARM_PLACEHOLDER_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml")
ONDEMAND_NODEPOOL_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml")
SPOT_NODEPOOL_MANIFEST_CONTENT=$(cat "${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml")
SCRIPT_CONTENT=$(cat "${REPO_ROOT}/scripts/_common.sh" "${REPO_ROOT}/scripts/up" "${REPO_ROOT}/scripts/verify" "${REPO_ROOT}/scripts/down" "${REPO_ROOT}/scripts/evaluate")

assert_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: Deployment' "the default inference manifest should remain the deployment entrypoint"
assert_not_contains "${DEPLOYMENT_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the default inference manifest should no longer include the HPA"
assert_contains "${RUNNING_HPA_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the running-policy manifest should define the HPA"
assert_contains "${RUNNING_HPA_MANIFEST_CONTENT}" 'name: vllm_requests_running' "the running-policy HPA should use the running-request metric target"
assert_contains "${RUNNING_HPA_MANIFEST_CONTENT}" 'averageValue: "128"' "the running-policy HPA should preserve the existing concurrency target"
assert_contains "${ACTIVE_PRESSURE_HPA_MANIFEST_CONTENT}" 'kind: HorizontalPodAutoscaler' "the active-pressure manifest should define the HPA"
assert_contains "${ACTIVE_PRESSURE_HPA_MANIFEST_CONTENT}" 'name: vllm_requests_active' "the active-pressure HPA should target the combined active-request metric"
assert_contains "${ACTIVE_PRESSURE_HPA_MANIFEST_CONTENT}" 'averageValue: "4"' "the active-pressure HPA should keep the checked-in default target"
assert_contains "${ADAPTER_VALUES_CONTENT}" 'vllm:num_requests_running' "the adapter should keep exposing the running-request metric"
assert_contains "${ADAPTER_VALUES_CONTENT}" 'vllm:num_requests_waiting' "the adapter should reference the waiting-request metric for active pressure"
assert_contains "${ADAPTER_VALUES_CONTENT}" 'vllm_requests_active' "the adapter should expose the combined active-request metric"
assert_contains "${ADAPTER_VALUES_CONTENT}" 'max_over_time' "the adapter should keep a short smoothing window so the HPA can see transient saturation"
assert_contains "${DASHBOARD_CONTENT}" 'max by (profile, resilience, policy, target)' "the experiment dashboard should group series by profile, resilience mode, policy, and HPA target"
assert_contains "${DASHBOARD_CONTENT}" '{{profile}}/{{resilience}}/{{policy}}/{{target}}' "the experiment dashboard legend should distinguish resilience mode and targets inside the same policy"
assert_contains "${DASHBOARD_CONTENT}" 'gpu_serving_measure_p95_estimated_queue_wait_seconds' "the experiment dashboard should surface the derived queue-wait summary metric"
assert_contains "${DASHBOARD_CONTENT}" 'gpu_serving_measure_peak_active_requests_per_gpu_node' "the experiment dashboard should surface the per-GPU active-request summary metric"
assert_contains "${SERVING_DASHBOARD_CONTENT}" 'P95 Estimated Queue Wait' "the serving dashboard should include the derived queue-wait panel"
assert_contains "${SCRIPT_CONTENT}" 'platform/observability' "the platform lifecycle should now reference observability manifests"
assert_contains "${SCRIPT_CONTENT}" 'platform/tests/gpu-load-test.yaml' "the evaluation flow should reference the load test manifest"
assert_contains "${SCRIPT_CONTENT}" 'platform/tests/gpu-warm-placeholder.yaml' "the evaluation flow should reference the warm placeholder workload"
assert_contains "${SCRIPT_CONTENT}" 'platform/karpenter/nodepool-gpu-serving-ondemand.yaml' "the platform lifecycle should install the on-demand serving NodePool"
assert_contains "${SCRIPT_CONTENT}" 'platform/karpenter/nodepool-gpu-serving-spot.yaml' "the platform lifecycle should install the spot serving NodePool"
assert_contains "${SCRIPT_CONTENT}" 'platform/inference/hpa-active-pressure.yaml' "the evaluation flow should know about the active-pressure HPA manifest"
assert_contains "${SCRIPT_CONTENT}" '--policy running|active-pressure|compare|sweep' "the evaluation CLI should expose the policy selector"
assert_contains "${SCRIPT_CONTENT}" '--resilience healthy|spot-unavailable' "the evaluation CLI should expose the resilience selector"
assert_contains "${SCRIPT_CONTENT}" '--active-target' "the evaluation CLI should expose the active-pressure target override"
assert_contains "${SCRIPT_CONTENT}" '--active-targets' "the evaluation CLI should expose the sweep target list override"
assert_contains "${SCRIPT_CONTENT}" '/metrics/job/gpu-serving-measure/profile/${EVALUATION_PROFILE}/resilience/${EVALUATION_RESILIENCE}/policy/${CURRENT_POLICY}/target/${CURRENT_HPA_TARGET_AVERAGE_VALUE}' "the evaluation flow should push summary metrics with resilience, policy, and target labels"
assert_contains "${SCRIPT_CONTENT}" 'p95_estimated_queue_wait_seconds' "the evaluation flow should report the derived queue-wait metric"
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
