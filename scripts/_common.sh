#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

COMMON_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${COMMON_DIR}/.." && pwd)

TF_DIR="${REPO_ROOT}/infra/env/dev"

APP_NAMESPACE="app"
MONITORING_NAMESPACE="monitoring"
KARPENTER_NAMESPACE="karpenter"

KARPENTER_RELEASE_NAME="karpenter"
KARPENTER_CRD_RELEASE_NAME="karpenter-crd"
KARPENTER_CHART_VERSION="1.9.0"
KARPENTER_NODECLASS_NAME="gpu-serving"
KARPENTER_NODEPOOL_NAME="gpu-serving"
KARPENTER_WARM_NODEPOOL_NAME="gpu-warm-1"
KARPENTER_SERVICE_ACCOUNT_NAME="karpenter"

ALB_CONTROLLER_RELEASE_NAME="aws-load-balancer-controller"
ALB_CONTROLLER_HELM_REPO_NAME="eks"
ALB_CONTROLLER_HELM_REPO_URL="https://aws.github.io/eks-charts"
ALB_CONTROLLER_CHART_VERSION="1.14.0"
ALB_CONTROLLER_SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
ALB_CONTROLLER_WEBHOOK_SERVICE="aws-load-balancer-webhook-service"

PROMETHEUS_COMMUNITY_HELM_REPO_NAME="prometheus-community"
PROMETHEUS_COMMUNITY_HELM_REPO_URL="https://prometheus-community.github.io/helm-charts"
KUBE_PROMETHEUS_STACK_RELEASE_NAME="kube-prometheus-stack"
KUBE_PROMETHEUS_STACK_CHART_VERSION="82.18.0"
KUBE_PROMETHEUS_STACK_OPERATOR_DEPLOYMENT="kube-prometheus-stack-operator"
KUBE_PROMETHEUS_STACK_GRAFANA_DEPLOYMENT="kube-prometheus-stack-grafana"
KUBE_PROMETHEUS_STACK_PROMETHEUS_STATEFULSET="prometheus-kube-prometheus-stack-prometheus"
KUBE_PROMETHEUS_STACK_PROMETHEUS_SERVICE="kube-prometheus-stack-prometheus"
PROMETHEUS_ADAPTER_RELEASE_NAME="prometheus-adapter"
PROMETHEUS_ADAPTER_CHART_VERSION="5.2.0"
PROMETHEUS_ADAPTER_DEPLOYMENT_NAME="prometheus-adapter"
PROMETHEUS_ADAPTER_APISERVICE_NAME="v1beta1.custom.metrics.k8s.io"
PUSHGATEWAY_DEPLOYMENT_NAME="pushgateway"
PUSHGATEWAY_SERVICE_NAME="pushgateway"
DCGM_EXPORTER_DAEMONSET_NAME="dcgm-exporter"

CONTROLLER_TIMEOUT_SECONDS="${CONTROLLER_TIMEOUT_SECONDS:-600}"
INGRESS_HOSTNAME_TIMEOUT_SECONDS="${INGRESS_HOSTNAME_TIMEOUT_SECONDS:-600}"
VERIFY_READY_TIMEOUT_SECONDS="${VERIFY_READY_TIMEOUT_SECONDS:-1200}"
VERIFY_RESPONSE_TIMEOUT_SECONDS="${VERIFY_RESPONSE_TIMEOUT_SECONDS:-1200}"
VERIFY_CLEANUP_TIMEOUT_SECONDS="${VERIFY_CLEANUP_TIMEOUT_SECONDS:-900}"
MONITORING_TIMEOUT_SECONDS="${MONITORING_TIMEOUT_SECONDS:-900}"
EVALUATE_SCALE_TIMEOUT_SECONDS="${EVALUATE_SCALE_TIMEOUT_SECONDS:-1200}"
EVALUATE_LOAD_TIMEOUT_SECONDS="${EVALUATE_LOAD_TIMEOUT_SECONDS:-1200}"
HTTP_REQUEST_TIMEOUT_SECONDS="${HTTP_REQUEST_TIMEOUT_SECONDS:-180}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-10}"

ALB_CONTROLLER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml"
KARPENTER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/karpenter/serviceaccount.yaml"
KARPENTER_NODECLASS_MANIFEST="${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml"
KARPENTER_NODEPOOL_MANIFEST="${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml"
KARPENTER_WARM_NODEPOOL_MANIFEST="${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml"
NVIDIA_DEVICE_PLUGIN_MANIFEST="${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml"
GPU_INFERENCE_DEPLOYMENT_MANIFEST="${REPO_ROOT}/platform/inference/vllm-openai.yaml"
GPU_INFERENCE_HPA_MANIFEST="${REPO_ROOT}/platform/inference/hpa.yaml"
GPU_INFERENCE_SERVICE_MANIFEST="${REPO_ROOT}/platform/inference/service.yaml"
GPU_INFERENCE_INGRESS_MANIFEST="${REPO_ROOT}/platform/inference/ingress.yaml"
GPU_LOAD_TEST_MANIFEST="${REPO_ROOT}/platform/tests/gpu-load-test.yaml"

OBSERVABILITY_KUBE_PROMETHEUS_STACK_VALUES="${REPO_ROOT}/platform/observability/kube-prometheus-stack-values.yaml"
OBSERVABILITY_PROMETHEUS_ADAPTER_VALUES="${REPO_ROOT}/platform/observability/prometheus-adapter-values.yaml"
OBSERVABILITY_VLLM_PODMONITOR_MANIFEST="${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml"
OBSERVABILITY_KARPENTER_PODMONITOR_MANIFEST="${REPO_ROOT}/platform/observability/karpenter-podmonitor.yaml"
OBSERVABILITY_PUSHGATEWAY_MANIFEST="${REPO_ROOT}/platform/observability/pushgateway.yaml"
OBSERVABILITY_DCGM_EXPORTER_MANIFEST="${REPO_ROOT}/platform/observability/dcgm-exporter.yaml"
OBSERVABILITY_SERVING_DASHBOARD_MANIFEST="${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml"
OBSERVABILITY_CAPACITY_DASHBOARD_MANIFEST="${REPO_ROOT}/platform/observability/dashboards/capacity-dashboard.yaml"
OBSERVABILITY_EXPERIMENT_DASHBOARD_MANIFEST="${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml"

GPU_INFERENCE_DEPLOYMENT_NAME="vllm-openai"
GPU_INFERENCE_SERVICE_NAME="vllm-openai"
GPU_INFERENCE_HPA_NAME="vllm-openai"
GPU_INFERENCE_INGRESS_NAME="vllm-openai-ingress"
GPU_INFERENCE_EDGE_PATH="/v1/completions"
GPU_LOAD_TEST_JOB_NAME="gpu-load-test"

CLUSTER_NAME=""
AWS_REGION=""
VPC_ID=""
ALB_CONTROLLER_ROLE_ARN=""

FAILURE_HINTS=()

print_stage_banner() {
  local number=$1
  local total=$2
  local label=$3

  printf '==> %s/%s %s\n' "${number}" "${total}" "${label}"
}

print_stage_result() {
  local result=$1
  local number=$2
  local total=$3
  local label=$4

  printf '%s %s/%s %s\n' "${result}" "${number}" "${total}" "${label}"
}

set_failure_hints() {
  FAILURE_HINTS=("$@")
}

print_failure_hints() {
  local command

  printf 'Follow-up commands:\n'
  for command in "${FAILURE_HINTS[@]}"; do
    printf '  %s\n' "${command}"
  done
}

run_stage() {
  local number=$1
  local total=$2
  local label=$3
  shift 3

  print_stage_banner "${number}" "${total}" "${label}"

  set +e
  "$@"
  local status=$?
  set -e

  if [[ "${status}" == "0" ]]; then
    print_stage_result "OK" "${number}" "${total}" "${label}"
    return 0
  fi

  print_stage_result "FAIL" "${number}" "${total}" "${label}"
  print_failure_hints
  exit "${status}"
}

require_commands() {
  local missing=()
  local command_name

  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      missing+=("${command_name}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    printf 'Missing required command(s): %s\n' "${missing[*]}" >&2
    return 1
  fi
}

retry() {
  local attempts=$1
  local delay_seconds=$2
  shift 2

  local attempt=1

  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi

    printf 'retry %d/%d in %ss: %s\n' "${attempt}" "${attempts}" "${delay_seconds}" "$*" >&2
    attempt=$((attempt + 1))
    sleep "${delay_seconds}"
  done
}

terraform_output_raw() {
  terraform -chdir="${TF_DIR}" output -raw "$1"
}

try_terraform_output_raw() {
  local name=$1
  local value

  set +e
  value=$(terraform -chdir="${TF_DIR}" output -raw "${name}" 2>/dev/null)
  local status=$?
  set -e

  if [[ "${status}" != "0" ]]; then
    return "${status}"
  fi

  printf '%s\n' "${value}"
}

load_cluster_context() {
  CLUSTER_NAME=$(terraform_output_raw cluster_name) || return 1
  AWS_REGION=$(terraform_output_raw aws_region) || return 1
  VPC_ID=$(terraform_output_raw vpc_id) || return 1
  ALB_CONTROLLER_ROLE_ARN=$(terraform_output_raw aws_load_balancer_controller_role_arn) || return 1
}

try_load_cluster_context() {
  local cluster_name
  local aws_region
  local vpc_id
  local alb_role_arn

  cluster_name=$(try_terraform_output_raw cluster_name) || return 1
  aws_region=$(try_terraform_output_raw aws_region) || return 1
  vpc_id=$(try_terraform_output_raw vpc_id) || return 1
  alb_role_arn=$(try_terraform_output_raw aws_load_balancer_controller_role_arn) || return 1

  CLUSTER_NAME=${cluster_name}
  AWS_REGION=${aws_region}
  VPC_ID=${vpc_id}
  ALB_CONTROLLER_ROLE_ARN=${alb_role_arn}
}

update_kubeconfig() {
  aws eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --alias "${CLUSTER_NAME}"
}

resource_exists() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=${3:-}

  if [[ -n "${resource_namespace}" ]]; then
    kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" >/dev/null 2>&1
    return $?
  fi

  kubectl get "${resource_kind}" "${resource_name}" >/dev/null 2>&1
}

namespace_exists() {
  kubectl get namespace "$1" >/dev/null 2>&1
}

wait_for_resource_existence() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    if resource_exists "${resource_kind}" "${resource_name}" "${resource_namespace}"; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for %s/%s to exist\n' "${resource_kind}" "${resource_name}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_resource_deletion() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    if ! resource_exists "${resource_kind}" "${resource_name}" "${resource_namespace}"; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for %s/%s deletion\n' "${resource_kind}" "${resource_name}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_service_endpoints() {
  local namespace=$1
  local service_name=$2
  local timeout_seconds=$3
  local start_time

  start_time=$(date +%s)

  while true; do
    local endpoints
    endpoints=$(kubectl get endpoints "${service_name}" \
      -n "${namespace}" \
      -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)

    if [[ -n "${endpoints}" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for service endpoints: %s/%s\n' "${namespace}" "${service_name}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_ingress_hostname() {
  local timeout_seconds=$1
  local start_time

  start_time=$(date +%s)

  while true; do
    local hostname
    hostname=$(kubectl get ingress "${GPU_INFERENCE_INGRESS_NAME}" \
      -n "${APP_NAMESPACE}" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

    if [[ -n "${hostname}" ]]; then
      printf '%s\n' "${hostname}"
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for ingress hostname: %s/%s\n' "${APP_NAMESPACE}" "${GPU_INFERENCE_INGRESS_NAME}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

gpu_node_count() {
  kubectl get nodes -l "karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME}" -o name 2>/dev/null | wc -l | tr -d ' '
}

all_gpu_node_count() {
  kubectl get nodes -l 'workload=gpu' -o name 2>/dev/null | wc -l | tr -d ' '
}

wait_for_gpu_nodes_at_least() {
  local expected=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    if (( $(gpu_node_count) >= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for at least %s GPU node(s)\n' "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_gpu_nodes_at_most() {
  local expected=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    if (( $(gpu_node_count) <= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for at most %s GPU node(s)\n' "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_all_gpu_nodes_at_least() {
  local expected=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    if (( $(all_gpu_node_count) >= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for at least %s total GPU node(s)\n' "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_all_gpu_nodes_at_most() {
  local expected=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    if (( $(all_gpu_node_count) <= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for at most %s total GPU node(s)\n' "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

deployment_ready_replicas() {
  local namespace=$1
  local deployment_name=$2

  kubectl get deployment "${deployment_name}" \
    -n "${namespace}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null | tr -d '[:space:]'
}

wait_for_deployment_ready_replicas_at_least() {
  local namespace=$1
  local deployment_name=$2
  local expected=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    local ready_replicas
    ready_replicas=$(deployment_ready_replicas "${namespace}" "${deployment_name}")
    ready_replicas=${ready_replicas:-0}

    if (( ready_replicas >= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for deployment %s/%s to have at least %s ready replica(s)\n' \
        "${namespace}" "${deployment_name}" "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_deployment_ready_replicas_at_most() {
  local namespace=$1
  local deployment_name=$2
  local expected=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    local ready_replicas
    ready_replicas=$(deployment_ready_replicas "${namespace}" "${deployment_name}")
    ready_replicas=${ready_replicas:-0}

    if (( ready_replicas <= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for deployment %s/%s to have at most %s ready replica(s)\n' \
        "${namespace}" "${deployment_name}" "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

hpa_desired_replicas() {
  local namespace=$1
  local hpa_name=$2

  kubectl get hpa "${hpa_name}" \
    -n "${namespace}" \
    -o jsonpath='{.status.desiredReplicas}' 2>/dev/null | tr -d '[:space:]'
}

wait_for_hpa_desired_replicas_at_least() {
  local namespace=$1
  local hpa_name=$2
  local expected=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    local desired_replicas
    desired_replicas=$(hpa_desired_replicas "${namespace}" "${hpa_name}")
    desired_replicas=${desired_replicas:-0}

    if (( desired_replicas >= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for HPA %s/%s to reach at least %s desired replica(s)\n' \
        "${namespace}" "${hpa_name}" "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_hpa_desired_replicas_at_most() {
  local namespace=$1
  local hpa_name=$2
  local expected=$3
  local timeout_seconds=$4
  local start_time

  start_time=$(date +%s)

  while true; do
    local desired_replicas
    desired_replicas=$(hpa_desired_replicas "${namespace}" "${hpa_name}")
    desired_replicas=${desired_replicas:-0}

    if (( desired_replicas <= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for HPA %s/%s to reach at most %s desired replica(s)\n' \
        "${namespace}" "${hpa_name}" "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

nodeclaim_count() {
  kubectl get nodeclaims -o name 2>/dev/null | wc -l | tr -d ' '
}

wait_for_nodeclaims_at_least() {
  local expected=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    if (( $(nodeclaim_count) >= expected )); then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for at least %s NodeClaim(s)\n' "${expected}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_job_completion() {
  local namespace=$1
  local job_name=$2
  local timeout_seconds=$3

  kubectl wait \
    --for=condition=complete \
    "job/${job_name}" \
    -n "${namespace}" \
    "--timeout=${timeout_seconds}s"
}

wait_for_http_200() {
  local url=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    local response_code
    response_code=$(curl -sS -o /dev/null -w '%{http_code}' \
      --connect-timeout 10 \
      --max-time "${HTTP_REQUEST_TIMEOUT_SECONDS}" \
      -H 'Content-Type: application/json' \
      -X POST \
      --data '{"model":"qwen2.5-0.5b","prompt":"Say hello from the public edge.","max_tokens":32,"temperature":0}' \
      "${url}" || true)

    if [[ "${response_code}" == "200" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for HTTP 200 from %s\n' "${url}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_apiservice_available() {
  local apiservice_name=$1
  local timeout_seconds=$2
  local start_time

  start_time=$(date +%s)

  while true; do
    local available_status
    available_status=$(kubectl get apiservice "${apiservice_name}" \
      -o jsonpath="{.status.conditions[?(@.type=='Available')].status}" 2>/dev/null || true)

    if [[ "${available_status}" == "True" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for APIService availability: %s\n' "${apiservice_name}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

wait_for_alb_deletion() {
  local dns_name=$1
  local timeout_seconds=$2
  local start_time

  if [[ -z "${dns_name}" ]]; then
    return 0
  fi

  start_time=$(date +%s)

  while true; do
    local alb_count
    alb_count=$(aws elbv2 describe-load-balancers \
      --region "${AWS_REGION}" \
      --query "length(LoadBalancers[?DNSName=='${dns_name}'])" \
      --output text)

    if [[ "${alb_count}" == "0" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      printf 'Timed out waiting for ALB deletion: %s\n' "${dns_name}" >&2
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

apply_aws_load_balancer_controller_crds() {
  local crd_manifest
  crd_manifest=$(mktemp)

  helm show crds "${ALB_CONTROLLER_HELM_REPO_NAME}/aws-load-balancer-controller" \
    --version "${ALB_CONTROLLER_CHART_VERSION}" > "${crd_manifest}" || {
      rm -f "${crd_manifest}"
      return 1
    }
  kubectl apply -f "${crd_manifest}" || {
    rm -f "${crd_manifest}"
    return 1
  }
  rm -f "${crd_manifest}"
}

apply_observability_manifests() {
  kubectl apply -f "${OBSERVABILITY_VLLM_PODMONITOR_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_KARPENTER_PODMONITOR_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_PUSHGATEWAY_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_DCGM_EXPORTER_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_SERVING_DASHBOARD_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_CAPACITY_DASHBOARD_MANIFEST}" || return 1
  kubectl apply -f "${OBSERVABILITY_EXPERIMENT_DASHBOARD_MANIFEST}" || return 1
}

delete_observability_manifests() {
  kubectl delete -f "${OBSERVABILITY_EXPERIMENT_DASHBOARD_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_CAPACITY_DASHBOARD_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_SERVING_DASHBOARD_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_DCGM_EXPORTER_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_PUSHGATEWAY_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_KARPENTER_PODMONITOR_MANIFEST}" --ignore-not-found=true || return 1
  kubectl delete -f "${OBSERVABILITY_VLLM_PODMONITOR_MANIFEST}" --ignore-not-found=true || return 1
}

install_observability_stack() {
  helm repo add "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}" "${PROMETHEUS_COMMUNITY_HELM_REPO_URL}" --force-update || return 1
  helm repo update || return 1
  helm upgrade --install "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" \
    "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}/kube-prometheus-stack" \
    -n "${MONITORING_NAMESPACE}" \
    --create-namespace \
    --wait \
    --timeout 15m \
    --version "${KUBE_PROMETHEUS_STACK_CHART_VERSION}" \
    -f "${OBSERVABILITY_KUBE_PROMETHEUS_STACK_VALUES}" || return 1
  kubectl rollout status "deployment/${KUBE_PROMETHEUS_STACK_OPERATOR_DEPLOYMENT}" -n "${MONITORING_NAMESPACE}" --timeout=10m || return 1
  kubectl rollout status "deployment/${KUBE_PROMETHEUS_STACK_GRAFANA_DEPLOYMENT}" -n "${MONITORING_NAMESPACE}" --timeout=10m || return 1
  kubectl rollout status "statefulset/${KUBE_PROMETHEUS_STACK_PROMETHEUS_STATEFULSET}" -n "${MONITORING_NAMESPACE}" --timeout=10m || return 1
  apply_observability_manifests || return 1
  wait_for_resource_existence deployment "${PUSHGATEWAY_DEPLOYMENT_NAME}" "${MONITORING_NAMESPACE}" 60 || return 1
  kubectl rollout status "deployment/${PUSHGATEWAY_DEPLOYMENT_NAME}" -n "${MONITORING_NAMESPACE}" --timeout=5m || return 1
  wait_for_resource_existence daemonset "${DCGM_EXPORTER_DAEMONSET_NAME}" "${MONITORING_NAMESPACE}" 60 || return 1
  helm upgrade --install "${PROMETHEUS_ADAPTER_RELEASE_NAME}" \
    "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}/prometheus-adapter" \
    -n "${MONITORING_NAMESPACE}" \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version "${PROMETHEUS_ADAPTER_CHART_VERSION}" \
    -f "${OBSERVABILITY_PROMETHEUS_ADAPTER_VALUES}" || return 1
  kubectl rollout status "deployment/${PROMETHEUS_ADAPTER_DEPLOYMENT_NAME}" -n "${MONITORING_NAMESPACE}" --timeout=10m || return 1
  wait_for_apiservice_available "${PROMETHEUS_ADAPTER_APISERVICE_NAME}" "${MONITORING_TIMEOUT_SECONDS}"
}

uninstall_observability_stack() {
  if namespace_exists "${MONITORING_NAMESPACE}"; then
    delete_observability_manifests || return 1
  fi

  if helm status "${PROMETHEUS_ADAPTER_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
    helm uninstall "${PROMETHEUS_ADAPTER_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" --wait || return 1
  fi
  if resource_exists apiservice "${PROMETHEUS_ADAPTER_APISERVICE_NAME}"; then
    wait_for_resource_deletion apiservice "${PROMETHEUS_ADAPTER_APISERVICE_NAME}" "" "${MONITORING_TIMEOUT_SECONDS}" || return 1
  fi

  if helm status "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
    helm uninstall "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" --wait || return 1
  fi

  if namespace_exists "${MONITORING_NAMESPACE}"; then
    kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found=true || return 1
    wait_for_resource_deletion namespace "${MONITORING_NAMESPACE}" "" "${MONITORING_TIMEOUT_SECONDS}"
  fi
}

ensure_namespace() {
  if ! namespace_exists "${APP_NAMESPACE}"; then
    kubectl create namespace "${APP_NAMESPACE}"
  fi
}

public_inference_url() {
  local hostname=$1
  printf 'http://%s%s\n' "${hostname}" "${GPU_INFERENCE_EDGE_PATH}"
}

format_duration() {
  local seconds=$1
  printf '%ss\n' "${seconds}"
}

command_string() {
  local command=("$@")
  local rendered=""
  local part

  for part in "${command[@]}"; do
    printf -v rendered '%s %q' "${rendered}" "${part}"
  done

  printf '%s\n' "${rendered# }"
}
