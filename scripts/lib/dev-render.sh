#!/usr/bin/env bash

describe_presence() {
  case "${1-}" in
    1)
      printf 'present'
      ;;
    0)
      printf 'missing'
      ;;
    *)
      printf 'unavailable'
      ;;
  esac
}

describe_readiness() {
  case "${1-}" in
    1)
      printf 'ready'
      ;;
    0)
      printf 'not ready'
      ;;
    *)
      printf 'unavailable'
      ;;
  esac
}

describe_availability() {
  case "${1-}" in
    1)
      printf 'available'
      ;;
    0)
      printf 'unavailable'
      ;;
    *)
      printf 'unavailable'
      ;;
  esac
}

describe_connectivity() {
  case "${1-}" in
    1)
      printf 'reachable'
      ;;
    0)
      printf 'unreachable'
      ;;
    *)
      printf 'unavailable'
      ;;
  esac
}

describe_warm_nodepool_state() {
  local present_state=${1-}
  local ready_state=${2-}

  case "${present_state}" in
    0)
      printf 'not present'
      ;;
    1)
      printf '%s' "$(describe_readiness "${ready_state}")"
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
  render_required_check "Terraform directory" "${DOCTOR_TF_DIR_OK}" "present (${TF_DIR})" "missing (${TF_DIR})"
  render_required_check "terraform" "${DOCTOR_CMD_TERRAFORM_OK}" "available" "missing from PATH"
  render_required_check "aws" "${DOCTOR_CMD_AWS_OK}" "available" "missing from PATH"
  render_required_check "kubectl" "${DOCTOR_CMD_KUBECTL_OK}" "available" "missing from PATH"
  render_required_check "helm" "${DOCTOR_CMD_HELM_OK}" "available" "missing from PATH"
  render_required_check "curl" "${DOCTOR_CMD_CURL_OK}" "available" "missing from PATH"

  log_section "checking Terraform context"
  render_required_check "cluster name" "${DOCTOR_CLUSTER_NAME_OK}" "${DOCTOR_CLUSTER_NAME}" "unavailable"
  render_required_check "AWS region" "${DOCTOR_AWS_REGION_OK}" "${DOCTOR_AWS_REGION}" "unavailable"

  log_section "checking Kubernetes access"
  render_required_check "cluster reachability" "${DOCTOR_CLUSTER_REACHABLE}" "reachable via context ${context_display}" "unreachable via context ${context_display}"

  log_section "checking platform resources"
  render_required_check "system nodes" "${DOCTOR_SYSTEM_NODES_OK}" "present" "missing"
  render_required_check "metrics-server deployment" "${DOCTOR_METRICS_SERVER_OK}" "present" "missing"
  render_required_check "Prometheus service" "${DOCTOR_PROMETHEUS_OK}" "present" "missing"
  render_required_check "Grafana deployment" "${DOCTOR_GRAFANA_OK}" "present" "missing"
  render_required_check "Prometheus Adapter deployment" "${DOCTOR_PROMETHEUS_ADAPTER_OK}" "present" "missing"
  render_required_check "custom metrics API" "${DOCTOR_CUSTOM_METRICS_API_OK}" "available" "unavailable"
  render_required_check "Pushgateway service" "${DOCTOR_PUSHGATEWAY_OK}" "present" "missing"
  render_required_check "DCGM exporter" "${DOCTOR_DCGM_EXPORTER_OK}" "present" "missing"
  render_required_check "Karpenter namespace" "${DOCTOR_KARPENTER_NAMESPACE_OK}" "present" "missing"
  render_required_check "Karpenter deployment" "${DOCTOR_KARPENTER_DEPLOYMENT_OK}" "present" "missing"
  render_required_check "Karpenter NodePool CRD" "${DOCTOR_NODEPOOL_CRD_OK}" "present" "missing"
  render_required_check "Karpenter NodeClaim CRD" "${DOCTOR_NODECLAIM_CRD_OK}" "present" "missing"
  render_required_check "Karpenter EC2NodeClass CRD" "${DOCTOR_EC2NODECLASS_CRD_OK}" "present" "missing"
  render_required_check "GPU NodePool" "${DOCTOR_GPU_NODEPOOL_OK}" "ready" "not ready"
  render_required_check "GPU EC2NodeClass" "${DOCTOR_GPU_NODECLASS_OK}" "present" "missing"
  render_required_check "vLLM PodMonitor" "${DOCTOR_VLLM_PODMONITOR_OK}" "present" "missing"
  render_required_check "Karpenter PodMonitor" "${DOCTOR_KARPENTER_PODMONITOR_OK}" "present" "missing"
  render_required_check "NVIDIA device plugin" "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}" "present" "missing"
  render_required_check "Inference service" "${DOCTOR_INFERENCE_SERVICE_OK}" "present" "missing"
  render_required_check "Inference ingress" "${DOCTOR_INFERENCE_INGRESS_OK}" "present" "missing"
  if [[ -n "${DOCTOR_WARM_NODEPOOL_PRESENT:-}" ]]; then
    log "warm GPU NodePool: $(describe_warm_nodepool_state "${DOCTOR_WARM_NODEPOOL_PRESENT}" "${DOCTOR_WARM_NODEPOOL_READY:-}")"
  fi

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
  "schema_version": 2,
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
    "terraform_available": $(json_nullable_bool "${DOCTOR_CMD_TERRAFORM_OK}"),
    "aws_available": $(json_nullable_bool "${DOCTOR_CMD_AWS_OK}"),
    "kubectl_available": $(json_nullable_bool "${DOCTOR_CMD_KUBECTL_OK}"),
    "helm_available": $(json_nullable_bool "${DOCTOR_CMD_HELM_OK}"),
    "curl_available": $(json_nullable_bool "${DOCTOR_CMD_CURL_OK}"),
    "terraform": $(json_nullable_bool "${DOCTOR_CMD_TERRAFORM_OK}"),
    "aws": $(json_nullable_bool "${DOCTOR_CMD_AWS_OK}"),
    "kubectl": $(json_nullable_bool "${DOCTOR_CMD_KUBECTL_OK}"),
    "helm": $(json_nullable_bool "${DOCTOR_CMD_HELM_OK}"),
    "curl": $(json_nullable_bool "${DOCTOR_CMD_CURL_OK}")
  },
  "kubernetes": {
    "cluster_reachable": $(json_nullable_bool "${DOCTOR_CLUSTER_REACHABLE}"),
    "reachable": $(json_nullable_bool "${DOCTOR_CLUSTER_REACHABLE}")
  },
  "platform": {
    "system_nodes_present": $(json_nullable_bool "${DOCTOR_SYSTEM_NODES_OK}"),
    "metrics_server_present": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "prometheus_service_present": $(json_nullable_bool "${DOCTOR_PROMETHEUS_OK}"),
    "grafana_deployment_present": $(json_nullable_bool "${DOCTOR_GRAFANA_OK}"),
    "prometheus_adapter_deployment_present": $(json_nullable_bool "${DOCTOR_PROMETHEUS_ADAPTER_OK}"),
    "custom_metrics_api_available": $(json_nullable_bool "${DOCTOR_CUSTOM_METRICS_API_OK}"),
    "pushgateway_service_present": $(json_nullable_bool "${DOCTOR_PUSHGATEWAY_OK}"),
    "dcgm_exporter_present": $(json_nullable_bool "${DOCTOR_DCGM_EXPORTER_OK}"),
    "karpenter_namespace_present": $(json_nullable_bool "${DOCTOR_KARPENTER_NAMESPACE_OK}"),
    "karpenter_deployment_present": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "nodepool_crd_present": $(json_nullable_bool "${DOCTOR_NODEPOOL_CRD_OK}"),
    "nodeclaim_crd_present": $(json_nullable_bool "${DOCTOR_NODECLAIM_CRD_OK}"),
    "ec2nodeclass_crd_present": $(json_nullable_bool "${DOCTOR_EC2NODECLASS_CRD_OK}"),
    "gpu_nodepool_ready": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "gpu_nodeclass_present": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "warm_gpu_nodepool_present": $(json_nullable_bool "${DOCTOR_WARM_NODEPOOL_PRESENT}"),
    "warm_gpu_nodepool_ready": $(json_nullable_bool "${DOCTOR_WARM_NODEPOOL_READY}"),
    "vllm_podmonitor_present": $(json_nullable_bool "${DOCTOR_VLLM_PODMONITOR_OK}"),
    "karpenter_podmonitor_present": $(json_nullable_bool "${DOCTOR_KARPENTER_PODMONITOR_OK}"),
    "nvidia_device_plugin_present": $(json_nullable_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}"),
    "inference_service_present": $(json_nullable_bool "${DOCTOR_INFERENCE_SERVICE_OK}"),
    "inference_ingress_present": $(json_nullable_bool "${DOCTOR_INFERENCE_INGRESS_OK}"),
    "metrics_server": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "prometheus": $(json_nullable_bool "${DOCTOR_PROMETHEUS_OK}"),
    "grafana": $(json_nullable_bool "${DOCTOR_GRAFANA_OK}"),
    "prometheus_adapter": $(json_nullable_bool "${DOCTOR_PROMETHEUS_ADAPTER_OK}"),
    "custom_metrics_api": $(json_nullable_bool "${DOCTOR_CUSTOM_METRICS_API_OK}"),
    "pushgateway": $(json_nullable_bool "${DOCTOR_PUSHGATEWAY_OK}"),
    "dcgm_exporter": $(json_nullable_bool "${DOCTOR_DCGM_EXPORTER_OK}"),
    "karpenter_namespace": $(json_nullable_bool "${DOCTOR_KARPENTER_NAMESPACE_OK}"),
    "karpenter_deployment": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "nodepool_crd": $(json_nullable_bool "${DOCTOR_NODEPOOL_CRD_OK}"),
    "nodeclaim_crd": $(json_nullable_bool "${DOCTOR_NODECLAIM_CRD_OK}"),
    "ec2nodeclass_crd": $(json_nullable_bool "${DOCTOR_EC2NODECLASS_CRD_OK}"),
    "gpu_nodepool": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "gpu_nodeclass": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "vllm_podmonitor": $(json_nullable_bool "${DOCTOR_VLLM_PODMONITOR_OK}"),
    "karpenter_podmonitor": $(json_nullable_bool "${DOCTOR_KARPENTER_PODMONITOR_OK}"),
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

  log "measurement: $(describe_readiness "${DOCTOR_READY}")"
  log "kubernetes context: $(describe_value "${DOCTOR_CURRENT_CONTEXT}")"
  log "terraform cluster name: $(describe_value "${DOCTOR_CLUSTER_NAME}")"
  log "terraform aws region: $(describe_value "${DOCTOR_AWS_REGION}")"

  log_section "resource counts"
  log "nodes: $(describe_value "${STATUS_NODE_COUNT}")"
  log "system nodes: $(describe_value "${STATUS_SYSTEM_NODE_COUNT}")"
  log "gpu nodes: $(describe_value "${STATUS_GPU_NODE_COUNT}")"
  log "nodepools: $(describe_value "${STATUS_NODEPOOL_COUNT}")"
  log "nodeclaims: $(describe_value "${STATUS_NODECLAIM_COUNT}")"
  log "app deployments: $(describe_value "${STATUS_APP_DEPLOYMENT_COUNT}")"
  log "app services: $(describe_value "${STATUS_APP_SERVICE_COUNT}")"
  log "app ingresses: $(describe_value "${STATUS_APP_INGRESS_COUNT}")"
  log "app hpas: $(describe_value "${STATUS_APP_HPA_COUNT}")"
  log "public inference URL: $(describe_value "${STATUS_PUBLIC_EDGE_URL}")"

  log_section "platform"
  log "metrics-server deployment: $(describe_presence "${DOCTOR_METRICS_SERVER_OK}")"
  log "Prometheus service: $(describe_presence "${DOCTOR_PROMETHEUS_OK}")"
  log "Grafana deployment: $(describe_presence "${DOCTOR_GRAFANA_OK}")"
  log "Prometheus Adapter deployment: $(describe_presence "${DOCTOR_PROMETHEUS_ADAPTER_OK}")"
  log "custom metrics API: $(describe_availability "${DOCTOR_CUSTOM_METRICS_API_OK}")"
  log "Pushgateway service: $(describe_presence "${DOCTOR_PUSHGATEWAY_OK}")"
  log "DCGM exporter: $(describe_presence "${DOCTOR_DCGM_EXPORTER_OK}")"
  log "Karpenter deployment: $(describe_presence "${DOCTOR_KARPENTER_DEPLOYMENT_OK}")"
  log "dynamic GPU NodePool: $(describe_readiness "${STATUS_DYNAMIC_GPU_NODEPOOL_READY}")"
  log "warm GPU NodePool: $(describe_warm_nodepool_state "${STATUS_WARM_NODEPOOL_PRESENT}" "${STATUS_WARM_NODEPOOL_READY}")"
  log "GPU EC2NodeClass: $(describe_presence "${DOCTOR_GPU_NODECLASS_OK}")"
  log "vLLM PodMonitor: $(describe_presence "${DOCTOR_VLLM_PODMONITOR_OK}")"
  log "Karpenter PodMonitor: $(describe_presence "${DOCTOR_KARPENTER_PODMONITOR_OK}")"
  log "NVIDIA device plugin: $(describe_presence "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}")"
  log "inference service: $(describe_presence "${DOCTOR_INFERENCE_SERVICE_OK}")"
  log "inference ingress: $(describe_presence "${DOCTOR_INFERENCE_INGRESS_OK}")"

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
  "schema_version": 2,
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
    "system_nodes": $(json_nullable_number "${STATUS_SYSTEM_NODE_COUNT}"),
    "gpu_nodes": $(json_nullable_number "${STATUS_GPU_NODE_COUNT}"),
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
    "system_nodes_present": $(json_nullable_bool "${DOCTOR_SYSTEM_NODES_OK}"),
    "metrics_server_present": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "prometheus_service_present": $(json_nullable_bool "${DOCTOR_PROMETHEUS_OK}"),
    "grafana_deployment_present": $(json_nullable_bool "${DOCTOR_GRAFANA_OK}"),
    "prometheus_adapter_deployment_present": $(json_nullable_bool "${DOCTOR_PROMETHEUS_ADAPTER_OK}"),
    "custom_metrics_api_available": $(json_nullable_bool "${DOCTOR_CUSTOM_METRICS_API_OK}"),
    "pushgateway_service_present": $(json_nullable_bool "${DOCTOR_PUSHGATEWAY_OK}"),
    "dcgm_exporter_present": $(json_nullable_bool "${DOCTOR_DCGM_EXPORTER_OK}"),
    "karpenter_deployment_present": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "gpu_nodepool_ready": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "warm_gpu_nodepool_present": $(json_nullable_bool "${STATUS_WARM_NODEPOOL_PRESENT}"),
    "warm_gpu_nodepool_ready": $(json_nullable_bool "${STATUS_WARM_NODEPOOL_READY}"),
    "gpu_nodeclass_present": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "vllm_podmonitor_present": $(json_nullable_bool "${DOCTOR_VLLM_PODMONITOR_OK}"),
    "karpenter_podmonitor_present": $(json_nullable_bool "${DOCTOR_KARPENTER_PODMONITOR_OK}"),
    "nvidia_device_plugin_present": $(json_nullable_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}"),
    "inference_service_present": $(json_nullable_bool "${DOCTOR_INFERENCE_SERVICE_OK}"),
    "inference_ingress_present": $(json_nullable_bool "${DOCTOR_INFERENCE_INGRESS_OK}"),
    "metrics_server": $(json_nullable_bool "${DOCTOR_METRICS_SERVER_OK}"),
    "prometheus": $(json_nullable_bool "${DOCTOR_PROMETHEUS_OK}"),
    "grafana": $(json_nullable_bool "${DOCTOR_GRAFANA_OK}"),
    "prometheus_adapter": $(json_nullable_bool "${DOCTOR_PROMETHEUS_ADAPTER_OK}"),
    "custom_metrics_api": $(json_nullable_bool "${DOCTOR_CUSTOM_METRICS_API_OK}"),
    "pushgateway": $(json_nullable_bool "${DOCTOR_PUSHGATEWAY_OK}"),
    "dcgm_exporter": $(json_nullable_bool "${DOCTOR_DCGM_EXPORTER_OK}"),
    "karpenter_deployment": $(json_nullable_bool "${DOCTOR_KARPENTER_DEPLOYMENT_OK}"),
    "gpu_nodepool": $(json_nullable_bool "${DOCTOR_GPU_NODEPOOL_OK}"),
    "gpu_nodeclass": $(json_nullable_bool "${DOCTOR_GPU_NODECLASS_OK}"),
    "vllm_podmonitor": $(json_nullable_bool "${DOCTOR_VLLM_PODMONITOR_OK}"),
    "karpenter_podmonitor": $(json_nullable_bool "${DOCTOR_KARPENTER_PODMONITOR_OK}"),
    "nvidia_device_plugin": $(json_nullable_bool "${DOCTOR_NVIDIA_DEVICE_PLUGIN_OK}"),
    "inference_service": $(json_nullable_bool "${DOCTOR_INFERENCE_SERVICE_OK}"),
    "inference_ingress": $(json_nullable_bool "${DOCTOR_INFERENCE_INGRESS_OK}")
  }
}
EOF
}
