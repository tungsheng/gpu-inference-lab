#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" TEST_TMPDIR="${TEST_TMPDIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/measure-state.sh"

  APP_NAMESPACE="app"
  DEPLOYMENT_NAME="vllm-openai"
  GPU_INFERENCE_INGRESS_NAME="vllm-openai-ingress"
  GPU_INFERENCE_EDGE_PATH="/v1/completions"
  LOAD_TEST_JOB_NAME="gpu-load-test"
  NODEPOOL_NAME="gpu-serving"
  MEASUREMENT_NODEPOOL_SELECTOR="karpenter.sh/nodepool=gpu-serving"
  NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME="nvidia-device-plugin-daemonset"
  initialize_measurement_context
  set_measurement_state_cache_key "42"
  first_gpu_node_name="gpu-a"
  KUBECTL_LOG="${TEST_TMPDIR}/kubectl.log"
  : > "${KUBECTL_LOG}"

  now_epoch() { printf "%s\n" "42"; }
  kubectl_name_count() { printf "%s\n" "2"; }
  resource_exists() {
    if [[ "$1" == "node" && "$2" == "gpu-a" ]]; then
      return 0
    fi
    return 1
  }
  kubectl() {
    printf "%s\n" "$*" >> "${KUBECTL_LOG}"
    case "$*" in
      *"get deployment vllm-openai -n app"*)
        printf "%s\n" "1|2"
        ;;
      *"get ingress vllm-openai-ingress -n app"*)
        printf "%s\n" "edge.example.com"
        ;;
      *"get hpa vllm-openai -n app"*)
        printf "%s\n" "1|2"
        ;;
      *"get pods -n app -l app=vllm-openai"*)
        printf "%s\n" "pod-1|Running|gpu-a|||Unschedulable"
        ;;
      *"get nodes -l workload=gpu"*)
        printf "%s\n" "gpu-a|1|g4dn.xlarge" "gpu-b|1|g5.xlarge"
        ;;
      *"get job gpu-load-test -n app"*)
        printf "%s\n" "1|0|0"
        ;;
      *"get pods -n app -l job-name=gpu-load-test"*)
        printf "%s\n" "load-pod|Running"
        ;;
      *"get pod load-pod -n app"*)
        printf "%s\n" ""
        ;;
      *"get daemonset nvidia-device-plugin-daemonset -n kube-system"*)
        printf "%s\n" "2|2"
        ;;
      *)
        printf "unexpected kubectl args: %s\n" "$*" >&2
        exit 1
        ;;
    esac
  }

  refresh_measurement_state "42"
  before_calls=$(wc -l < "${KUBECTL_LOG}" | tr -d " ")
  summary=$(serving_state_snapshot)
  load_summary=$(serving_and_load_state_snapshot)
  gpu_summary=$(first_gpu_capacity_snapshot)
  edge_summary=$(edge_state_snapshot)
  edge_url=$(inference_edge_url)
  ensure_measurement_state_current
  after_calls=$(wc -l < "${KUBECTL_LOG}" | tr -d " ")

  printf "summary=%s\n" "${summary}"
  printf "load_summary=%s\n" "${load_summary}"
  printf "gpu_summary=%s\n" "${gpu_summary}"
  printf "edge_summary=%s\n" "${edge_summary}"
  printf "edge_url=%s\n" "${edge_url}"
  printf "cache_calls=%s->%s\n" "${before_calls}" "${after_calls}"
'

assert_status 0 "${COMMAND_STATUS}" "measure-state snapshot helpers should succeed"
assert_contains "${COMMAND_OUTPUT}" "summary=pod Running (Unschedulable) on gpu-a | replicas ready 1/2 | gpu nodes 2 | nodeclaims 2 | hpa current/desired 1/2" "serving_state_snapshot should summarize cached state"
assert_contains "${COMMAND_OUTPUT}" "load_summary=pod Running (Unschedulable) on gpu-a | replicas ready 1/2 | gpu nodes 2 | nodeclaims 2 | hpa current/desired 1/2 | load running" "serving_and_load_state_snapshot should include load state"
assert_contains "${COMMAND_OUTPUT}" "gpu_summary=node gpu-a | gpu allocatable 1 | device plugin 2/2 | pod Running (Unschedulable) on gpu-a | replicas ready 1/2 | gpu nodes 2 | nodeclaims 2 | hpa current/desired 1/2" "first_gpu_capacity_snapshot should include node and plugin details"
assert_contains "${COMMAND_OUTPUT}" "edge_summary=edge http://edge.example.com/v1/completions | pod Running (Unschedulable) on gpu-a | replicas ready 1/2 | gpu nodes 2 | nodeclaims 2 | hpa current/desired 1/2" "edge_state_snapshot should include the public inference URL"
assert_contains "${COMMAND_OUTPUT}" "edge_url=http://edge.example.com/v1/completions" "inference_edge_url should render the public inference URL"
assert_contains "${COMMAND_OUTPUT}" "cache_calls=9->9" "ensure_measurement_state_current should reuse the cached snapshot for the same key"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/measure-state.sh"

  ensure_measurement_state_current() { return 0; }

  STATE_FIRST_POD_NAME="pod-1"
  STATE_FIRST_POD_PHASE="Pending"
  STATE_FIRST_POD_NODE_NAME=""
  STATE_FIRST_POD_WAITING_REASON="CrashLoopBackOff"
  STATE_FIRST_POD_TERMINATED_REASON=""
  STATE_FIRST_POD_SCHEDULING_REASON=""

  STATE_LOAD_TEST_EXISTS="1"
  STATE_LOAD_TEST_FAILED="0"
  STATE_LOAD_TEST_POD_NAME="load-pod"
  STATE_LOAD_TEST_POD_PHASE="Pending"
  STATE_LOAD_TEST_POD_REASON="ImagePullBackOff"
  LOAD_TEST_JOB_NAME="gpu-load-test"

  printf "serving=%s\n" "$(fatal_serving_state)"
  printf "load=%s\n" "$(fatal_load_test_state)"
  printf "scale_out=%s\n" "$(fatal_scale_out_state)"
'

assert_status 0 "${COMMAND_STATUS}" "measure-state fatal helpers should succeed"
assert_contains "${COMMAND_OUTPUT}" "serving=serving pod pod-1 entered CrashLoopBackOff" "fatal_serving_state should report serving pod failures"
assert_contains "${COMMAND_OUTPUT}" "load=load-test pod load-pod entered ImagePullBackOff" "fatal_load_test_state should report load pod failures"
assert_contains "${COMMAND_OUTPUT}" "scale_out=serving pod pod-1 entered CrashLoopBackOff" "fatal_scale_out_state should prioritize serving failures"
