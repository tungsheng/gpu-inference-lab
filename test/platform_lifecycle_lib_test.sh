#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/dev-environment-paths.sh"
  source "${REPO_ROOT}/scripts/lib/platform-install.sh"

  SCRIPT_NAME="platform-install-test"
  run_step() {
    local step=$1
    shift
    printf "step:%s\n" "${step}"
    "$@"
  }
  install_aws_load_balancer_controller() { printf "%s\n" "call:alb-controller"; }
  install_metrics_server() { printf "%s\n" "call:metrics-server"; }
  install_karpenter() { printf "%s\n" "call:karpenter"; }
  retry_command() { shift 2; printf "call:retry:%s\n" "$*"; }
  kubectl() { printf "call:kubectl:%s\n" "$*"; }
  ensure_namespace() { printf "call:namespace:%s\n" "$1"; }
  install_test_app() { printf "%s\n" "call:test-app"; }
  run_post_apply_flow
'

assert_status 0 "${COMMAND_STATUS}" "platform install flow should orchestrate the extracted install helpers"
assert_contains "${COMMAND_OUTPUT}" $'call:alb-controller\nstep:installing metrics server\ncall:metrics-server\nstep:installing Karpenter\ncall:karpenter' "platform install flow should run controller, metrics, and Karpenter setup in order"
assert_contains "${COMMAND_OUTPUT}" $'step:installing NVIDIA device plugin\ncall:retry:kubectl apply -f '"${REPO_ROOT}"'/platform/system/nvidia-device-plugin.yaml' "platform install flow should apply the NVIDIA device plugin through the shared retry helper"
assert_contains "${COMMAND_OUTPUT}" $'step:ensuring app namespace exists\ncall:namespace:app\ncall:test-app' "platform install flow should ensure the app namespace before installing the sample app"

# shellcheck disable=SC2016
run_and_capture env REPO_ROOT="${REPO_ROOT}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/dev-environment-paths.sh"
  source "${REPO_ROOT}/scripts/lib/platform-destroy.sh"

  SCRIPT_NAME="platform-destroy-test"
  CLUSTER_CONTEXT_AWS_REGION="us-west-2"
  run_step() {
    local step=$1
    shift
    printf "step:%s\n" "${step}"
    "$@"
  }
  kubectl() {
    if [[ "$*" == *"get ingress "* ]]; then
      printf "%s\n" "example-alb.us-west-2.elb.amazonaws.com"
      return 0
    fi
    printf "call:kubectl:%s\n" "$*"
  }
  delete_test_app() { printf "call:test-app:%s|%s\n" "$1" "$2"; }
  delete_gpu_workloads() { printf "%s\n" "call:gpu-workloads"; }
  delete_karpenter_stack() { printf "%s\n" "call:karpenter-stack"; }
  delete_nvidia_device_plugin() { printf "%s\n" "call:nvidia-device-plugin"; }
  delete_metrics_server() { printf "%s\n" "call:metrics-server"; }
  delete_app_namespace() { printf "%s\n" "call:app-namespace"; }
  delete_aws_load_balancer_controller() { printf "%s\n" "call:alb-controller"; }
  run_destroy_cleanup_flow
'

assert_status 0 "${COMMAND_STATUS}" "platform destroy flow should orchestrate the extracted teardown helpers"
assert_contains "${COMMAND_OUTPUT}" $'call:test-app:example-alb.us-west-2.elb.amazonaws.com|us-west-2\ncall:gpu-workloads\ncall:karpenter-stack' "platform destroy flow should begin with app, GPU workload, and Karpenter cleanup"
assert_contains "${COMMAND_OUTPUT}" $'step:deleting NVIDIA device plugin\ncall:nvidia-device-plugin\ncall:metrics-server\nstep:deleting app namespace\ncall:app-namespace\ncall:alb-controller' "platform destroy flow should finish with NVIDIA, namespace, and controller cleanup in order"
