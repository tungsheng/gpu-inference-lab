#!/usr/bin/env bash

describe_bool() {
  case "${1-}" in
    1)
      printf 'yes'
      ;;
    0)
      printf 'no'
      ;;
    *)
      printf 'unavailable'
      ;;
  esac
}

describe_value() {
  if [[ -n "${1-}" ]]; then
    printf '%s' "${1}"
    return 0
  fi

  printf 'unavailable'
}

render_required_check() {
  local label=$1
  local result=$2
  local success_message=$3
  local failure_message=$4

  if [[ "${result}" == "1" ]]; then
    log_success "${label}: ${success_message}"
    return 0
  fi

  if [[ "${result}" == "0" ]]; then
    log_error "${label}: ${failure_message}"
    return 0
  fi

  log_warn "${label}: unavailable"
}

render_doctor_text() {
  local summary
  local context_display

  summary=$(doctor_summary)
  context_display=$(describe_value "${DOCTOR_CURRENT_CONTEXT}")

  log_section "checking local prerequisites"
  render_required_check "Terraform directory" "${DOCTOR_TF_DIR_OK}" "${TF_DIR}" "not found: ${TF_DIR}"
  render_required_check "terraform" "${DOCTOR_CMD_TERRAFORM_OK}" "installed" "missing from PATH"
  render_required_check "aws" "${DOCTOR_CMD_AWS_OK}" "installed" "missing from PATH"
  render_required_check "kubectl" "${DOCTOR_CMD_KUBECTL_OK}" "installed" "missing from PATH"
  render_required_check "helm" "${DOCTOR_CMD_HELM_OK}" "installed" "missing from PATH"
  render_required_check "curl" "${DOCTOR_CMD_CURL_OK}" "installed" "missing from PATH"

  log_section "checking Terraform context"
  render_required_check "cluster name" "${DOCTOR_CLUSTER_NAME_OK}" "${DOCTOR_CLUSTER_NAME}" "Terraform output unavailable"
  render_required_check "AWS region" "${DOCTOR_AWS_REGION_OK}" "${DOCTOR_AWS_REGION}" "Terraform output unavailable"

  log_section "checking Kubernetes access"
  render_required_check "kubectl connectivity" "${DOCTOR_CLUSTER_REACHABLE}" "reachable via context ${context_display}" "cannot reach cluster via context ${context_display}"

  log_section "checking platform resources"
  render_required_check "metrics-server deployment" "${DOCTOR_METRICS_SERVER_OK}" "present" "missing"
  render_required_check "karpenter namespace" "${DOCTOR_KARPENTER_NAMESPACE_OK}" "present" "missing"
  render_required_check "karpenter deployment" "${DOCTOR_KARPENTER_DEPLOYMENT_OK}" "present" "missing"
  render_required_check "Karpenter NodePool CRD" "${DOCTOR_NODEPOOL_CRD_OK}" "present" "missing"
  render_required_check "Karpenter NodeClaim CRD" "${DOCTOR_NODECLAIM_CRD_OK}" "present" "missing"
  render_required_check "Karpenter EC2NodeClass CRD" "${DOCTOR_EC2NODECLASS_CRD_OK}" "present" "missing"
  render_required_check "GPU NodePool" "${DOCTOR_GPU_NODEPOOL_OK}" "present" "missing"
  render_required_check "GPU EC2NodeClass" "${DOCTOR_GPU_NODECLASS_OK}" "present" "missing"
  render_required_check "NVIDIA device plugin" "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}" "present" "missing"
  render_required_check "inference service" "${DOCTOR_INFERENCE_SERVICE_OK}" "present" "missing"
  render_required_check "inference ingress" "${DOCTOR_INFERENCE_INGRESS_OK}" "present" "missing"

  log_section "doctor summary"
  if [[ "${DOCTOR_READY}" == "1" ]]; then
    log_success "${summary} (${DOCTOR_PASSED_CHECKS}/${DOCTOR_TOTAL_CHECKS} required checks passed)"
    return 0
  fi

  log_error "${summary} (${DOCTOR_PASSED_CHECKS}/${DOCTOR_TOTAL_CHECKS} required checks passed)"
}

render_doctor_json() {
  local summary

  summary=$(doctor_summary)

  cat <<EOF
{
  "ok": $(json_nullable_bool "${DOCTOR_READY}"),
  "summary": $(json_string "${summary}"),
  "passed_checks": $(json_nullable_number "${DOCTOR_PASSED_CHECKS}"),
  "total_checks": $(json_nullable_number "${DOCTOR_TOTAL_CHECKS}"),
  "context": $(json_nullable_string "${DOCTOR_CURRENT_CONTEXT}"),
  "terraform": {
    "directory_present": $(json_nullable_bool "${DOCTOR_TF_DIR_OK}"),
    "cluster_name": $(json_nullable_string "${DOCTOR_CLUSTER_NAME}"),
    "aws_region": $(json_nullable_string "${DOCTOR_AWS_REGION}")
  },
  "local": {
    "terraform": $(json_nullable_bool "${DOCTOR_CMD_TERRAFORM_OK}"),
    "aws": $(json_nullable_bool "${DOCTOR_CMD_AWS_OK}"),
    "kubectl": $(json_nullable_bool "${DOCTOR_CMD_KUBECTL_OK}"),
    "helm": $(json_nullable_bool "${DOCTOR_CMD_HELM_OK}"),
    "curl": $(json_nullable_bool "${DOCTOR_CMD_CURL_OK}")
  },
  "kubernetes": {
    "reachable": $(json_nullable_bool "${DOCTOR_CLUSTER_REACHABLE}")
  },
  "platform": {
    "metrics_server": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "karpenter_namespace": $(json_nullable_bool "${DOCTOR_KARPENTER_NAMESPACE_OK}"),
    "karpenter_deployment": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "nodepool_crd": $(json_nullable_bool "${DOCTOR_NODEPOOL_CRD_OK}"),
    "nodeclaim_crd": $(json_nullable_bool "${DOCTOR_NODECLAIM_CRD_OK}"),
    "ec2nodeclass_crd": $(json_nullable_bool "${DOCTOR_EC2NODECLASS_CRD_OK}"),
    "gpu_nodepool": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "gpu_nodeclass": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "nvidia_device_plugin": $(json_nullable_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}"),
    "inference_service": $(json_nullable_bool "${DOCTOR_INFERENCE_SERVICE_OK}"),
    "inference_ingress": $(json_nullable_bool "${DOCTOR_INFERENCE_INGRESS_OK}")
  }
}
EOF
}

render_status_verbose_snapshot() {
  kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide
  kubectl get deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" -n kube-system || true
  kubectl get deployment "${KARPENTER_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" || true
  kubectl get nodepools || true
  kubectl get ec2nodeclasses || true
  kubectl get daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" -n kube-system || true
  kubectl get ingress -n "${APP_NAMESPACE}" || true
  kubectl get deployment -n "${APP_NAMESPACE}" || true
  kubectl get hpa -n "${APP_NAMESPACE}" || true
}

render_status_text() {
  local verbose_mode=$1
  local summary

  summary=$(status_summary)

  log_section "cluster status"
  if [[ "${STATUS_OK}" == "1" ]]; then
    log_success "${summary}"
  else
    log_error "${summary}"
  fi

  log "measurement readiness: $(describe_bool "${DOCTOR_READY}")"
  log "kubernetes context: $(describe_value "${DOCTOR_CURRENT_CONTEXT}")"
  log "terraform cluster name: $(describe_value "${DOCTOR_CLUSTER_NAME}")"
  log "terraform aws region: $(describe_value "${DOCTOR_AWS_REGION}")"

  log_section "resource counts"
  log "nodes: $(describe_value "${STATUS_NODE_COUNT}")"
  log "nodepools: $(describe_value "${STATUS_NODEPOOL_COUNT}")"
  log "nodeclaims: $(describe_value "${STATUS_NODECLAIM_COUNT}")"
  log "app deployments: $(describe_value "${STATUS_APP_DEPLOYMENT_COUNT}")"
  log "app services: $(describe_value "${STATUS_APP_SERVICE_COUNT}")"
  log "app ingresses: $(describe_value "${STATUS_APP_INGRESS_COUNT}")"
  log "app hpas: $(describe_value "${STATUS_APP_HPA_COUNT}")"
  log "public inference URL: $(describe_value "${STATUS_PUBLIC_EDGE_URL}")"

  log_section "platform"
  log "metrics-server: $(describe_bool "${DOCTOR_METRICS_SERVER_OK}")"
  log "karpenter deployment: $(describe_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}")"
  log "GPU NodePool: $(describe_bool "${DOCTOR_GPU_NODEPOOL_OK}")"
  log "GPU EC2NodeClass: $(describe_bool "${DOCTOR_GPU_NODECLASS_OK}")"
  log "NVIDIA device plugin: $(describe_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}")"
  log "inference service: $(describe_bool "${DOCTOR_INFERENCE_SERVICE_OK}")"
  log "inference ingress: $(describe_bool "${DOCTOR_INFERENCE_INGRESS_OK}")"

  if [[ "${verbose_mode}" != "1" || "${STATUS_OK}" != "1" ]]; then
    return 0
  fi

  log_section "detailed snapshot"
  render_status_verbose_snapshot
}

render_status_json() {
  local summary

  summary=$(status_summary)

  cat <<EOF
{
  "ok": $(json_nullable_bool "${STATUS_OK}"),
  "summary": $(json_string "${summary}"),
  "ready_for_measurement": $(json_nullable_bool "${DOCTOR_READY}"),
  "context": $(json_nullable_string "${DOCTOR_CURRENT_CONTEXT}"),
  "terraform": {
    "cluster_name": $(json_nullable_string "${DOCTOR_CLUSTER_NAME}"),
    "aws_region": $(json_nullable_string "${DOCTOR_AWS_REGION}")
  },
  "counts": {
    "nodes": $(json_nullable_number "${STATUS_NODE_COUNT}"),
    "nodepools": $(json_nullable_number "${STATUS_NODEPOOL_COUNT}"),
    "nodeclaims": $(json_nullable_number "${STATUS_NODECLAIM_COUNT}"),
    "app_deployments": $(json_nullable_number "${STATUS_APP_DEPLOYMENT_COUNT}"),
    "app_services": $(json_nullable_number "${STATUS_APP_SERVICE_COUNT}"),
    "app_ingresses": $(json_nullable_number "${STATUS_APP_INGRESS_COUNT}"),
    "app_hpas": $(json_nullable_number "${STATUS_APP_HPA_COUNT}")
  },
  "public_edge": {
    "hostname": $(json_nullable_string "${STATUS_PUBLIC_EDGE_HOSTNAME}"),
    "url": $(json_nullable_string "${STATUS_PUBLIC_EDGE_URL}")
  },
  "platform": {
    "metrics_server": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "karpenter_deployment": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "gpu_nodepool": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "gpu_nodeclass": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "nvidia_device_plugin": $(json_nullable_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}"),
    "inference_service": $(json_nullable_bool "${DOCTOR_INFERENCE_SERVICE_OK}"),
    "inference_ingress": $(json_nullable_bool "${DOCTOR_INFERENCE_INGRESS_OK}")
  }
}
EOF
}
