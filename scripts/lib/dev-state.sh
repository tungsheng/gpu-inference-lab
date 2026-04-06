#!/usr/bin/env bash

# Shared doctor/status state is consumed by the dev CLI and render helpers.
# shellcheck disable=SC2034
readonly DOCTOR_REQUIRED_CHECKS=(
  DOCTOR_TF_DIR_OK
  DOCTOR_CMD_TERRAFORM_OK
  DOCTOR_CMD_AWS_OK
  DOCTOR_CMD_KUBECTL_OK
  DOCTOR_CMD_HELM_OK
  DOCTOR_CMD_CURL_OK
  DOCTOR_CLUSTER_NAME_OK
  DOCTOR_AWS_REGION_OK
  DOCTOR_CLUSTER_REACHABLE
  DOCTOR_METRICS_SERVER_OK
  DOCTOR_KARPENTER_NAMESPACE_OK
  DOCTOR_KARPENTER_DEPLOYMENT_OK
  DOCTOR_NODEPOOL_CRD_OK
  DOCTOR_NODECLAIM_CRD_OK
  DOCTOR_EC2NODECLASS_CRD_OK
  DOCTOR_GPU_NODEPOOL_OK
  DOCTOR_GPU_NODECLASS_OK
  DOCTOR_NVIDIA_DEVICE_PLUGIN_OK
  DOCTOR_INFERENCE_SERVICE_OK
  DOCTOR_INFERENCE_INGRESS_OK
)

command_available() {
  command -v "$1" >/dev/null 2>&1
}

check_result() {
  if "$@"; then
    printf '1'
    return 0
  fi

  printf '0'
}

count_true_checks() {
  local check_name
  local count=0

  for check_name in "$@"; do
    if [[ "${!check_name:-}" == "1" ]]; then
      count=$((count + 1))
    fi
  done

  printf '%s' "${count}"
}

all_checks_passed() {
  local check_name

  for check_name in "$@"; do
    if [[ "${!check_name:-}" != "1" ]]; then
      return 1
    fi
  done

  return 0
}

reset_doctor_state() {
  local check_name

  for check_name in "${DOCTOR_REQUIRED_CHECKS[@]}"; do
    printf -v "${check_name}" '%s' ""
  done

  DOCTOR_CURRENT_CONTEXT=""
  DOCTOR_CLUSTER_NAME=""
  DOCTOR_AWS_REGION=""
  DOCTOR_PASSED_CHECKS=0
  DOCTOR_TOTAL_CHECKS=${#DOCTOR_REQUIRED_CHECKS[@]}
  DOCTOR_READY=0
}

collect_doctor_state() {
  reset_doctor_state

  DOCTOR_TF_DIR_OK=$(check_result test -d "${TF_DIR}")
  DOCTOR_CMD_TERRAFORM_OK=$(check_result command_available terraform)
  DOCTOR_CMD_AWS_OK=$(check_result command_available aws)
  DOCTOR_CMD_KUBECTL_OK=$(check_result command_available kubectl)
  DOCTOR_CMD_HELM_OK=$(check_result command_available helm)
  DOCTOR_CMD_CURL_OK=$(check_result command_available curl)

  if [[ "${DOCTOR_TF_DIR_OK}" == "1" && "${DOCTOR_CMD_TERRAFORM_OK}" == "1" ]]; then
    DOCTOR_CLUSTER_NAME=$(terraform_output_optional "${TF_DIR}" cluster_name)
    DOCTOR_AWS_REGION=$(terraform_output_optional "${TF_DIR}" aws_region)
    DOCTOR_CLUSTER_NAME_OK=$(check_result test -n "${DOCTOR_CLUSTER_NAME}")
    DOCTOR_AWS_REGION_OK=$(check_result test -n "${DOCTOR_AWS_REGION}")
  fi

  if [[ "${DOCTOR_CMD_KUBECTL_OK}" == "1" ]]; then
    DOCTOR_CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || true)
    DOCTOR_CLUSTER_REACHABLE=$(check_result verify_cluster_connectivity)
  fi

  if [[ "${DOCTOR_CLUSTER_REACHABLE:-}" == "1" ]]; then
    DOCTOR_METRICS_SERVER_OK=$(check_result resource_exists deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" kube-system)
    DOCTOR_KARPENTER_NAMESPACE_OK=$(check_result namespace_exists "${KARPENTER_NAMESPACE}")
    DOCTOR_KARPENTER_DEPLOYMENT_OK=$(check_result resource_exists deployment "${KARPENTER_RELEASE_NAME}" "${KARPENTER_NAMESPACE}")
    DOCTOR_NODEPOOL_CRD_OK=$(check_result crd_exists nodepools.karpenter.sh)
    DOCTOR_NODECLAIM_CRD_OK=$(check_result crd_exists nodeclaims.karpenter.sh)
    DOCTOR_EC2NODECLASS_CRD_OK=$(check_result crd_exists ec2nodeclasses.karpenter.k8s.aws)
    DOCTOR_GPU_NODEPOOL_OK=$(check_result resource_exists nodepool "${KARPENTER_NODEPOOL_NAME}")
    DOCTOR_GPU_NODECLASS_OK=$(check_result resource_exists ec2nodeclass "${KARPENTER_NODECLASS_NAME}")
    DOCTOR_NVIDIA_DEVICE_PLUGIN_OK=$(check_result resource_exists daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" kube-system)
    DOCTOR_INFERENCE_SERVICE_OK=$(check_result resource_exists service "${GPU_INFERENCE_SERVICE_NAME}" "${APP_NAMESPACE}")
    DOCTOR_INFERENCE_INGRESS_OK=$(check_result resource_exists ingress "${GPU_INFERENCE_INGRESS_NAME}" "${APP_NAMESPACE}")
  fi

  DOCTOR_PASSED_CHECKS=$(count_true_checks "${DOCTOR_REQUIRED_CHECKS[@]}")
  DOCTOR_READY=$(check_result all_checks_passed "${DOCTOR_REQUIRED_CHECKS[@]}")
}

doctor_summary() {
  if [[ "${DOCTOR_READY}" == "1" ]]; then
    printf 'environment ready for measurements'
    return 0
  fi

  if [[ "${DOCTOR_CMD_KUBECTL_OK:-}" == "0" ]]; then
    printf 'kubectl is unavailable on this machine'
    return 0
  fi

  if [[ "${DOCTOR_CMD_CURL_OK:-}" == "0" ]]; then
    printf 'curl is unavailable on this machine'
    return 0
  fi

  if [[ "${DOCTOR_CLUSTER_REACHABLE:-}" == "0" ]]; then
    printf 'kubectl cannot reach the configured cluster'
    return 0
  fi

  printf 'environment is not ready for measurements'
}

reset_status_state() {
  STATUS_NODE_COUNT=""
  STATUS_NODEPOOL_COUNT=""
  STATUS_NODECLAIM_COUNT=""
  STATUS_APP_DEPLOYMENT_COUNT=""
  STATUS_APP_SERVICE_COUNT=""
  STATUS_APP_INGRESS_COUNT=""
  STATUS_APP_HPA_COUNT=""
  STATUS_PUBLIC_EDGE_HOSTNAME=""
  STATUS_PUBLIC_EDGE_URL=""
  STATUS_OK=0
}

collect_status_state() {
  reset_status_state
  collect_doctor_state

  if [[ "${DOCTOR_CLUSTER_REACHABLE:-}" != "1" ]]; then
    return 0
  fi

  STATUS_NODE_COUNT=$(kubectl_name_count nodes)
  STATUS_APP_DEPLOYMENT_COUNT=$(kubectl_name_count deployment "${APP_NAMESPACE}")
  STATUS_APP_SERVICE_COUNT=$(kubectl_name_count service "${APP_NAMESPACE}")
  STATUS_APP_INGRESS_COUNT=$(kubectl_name_count ingress "${APP_NAMESPACE}")
  STATUS_APP_HPA_COUNT=$(kubectl_name_count hpa "${APP_NAMESPACE}")
  STATUS_PUBLIC_EDGE_HOSTNAME=$(ingress_hostname "${GPU_INFERENCE_INGRESS_NAME}" "${APP_NAMESPACE}")

  if [[ -z "${STATUS_PUBLIC_EDGE_HOSTNAME}" ]]; then
    STATUS_PUBLIC_EDGE_HOSTNAME=$(ingress_hostname "${TEST_APP_INGRESS_NAME}" "${APP_NAMESPACE}")
  fi

  if [[ -n "${STATUS_PUBLIC_EDGE_HOSTNAME}" ]]; then
    STATUS_PUBLIC_EDGE_URL="http://${STATUS_PUBLIC_EDGE_HOSTNAME}${GPU_INFERENCE_EDGE_PATH}"
  fi

  if api_resource_exists "nodepools.karpenter.sh"; then
    STATUS_NODEPOOL_COUNT=$(kubectl_name_count nodepools)
  fi

  if api_resource_exists "nodeclaims.karpenter.sh"; then
    STATUS_NODECLAIM_COUNT=$(kubectl_name_count nodeclaims)
  fi

  STATUS_OK=1
}

status_summary() {
  if [[ "${STATUS_OK}" != "1" ]]; then
    printf 'cluster status unavailable'
    return 0
  fi

  if [[ "${DOCTOR_READY}" == "1" ]]; then
    printf 'cluster reachable and ready for measurements'
    return 0
  fi

  printf 'cluster reachable but missing measurement prerequisites'
}
