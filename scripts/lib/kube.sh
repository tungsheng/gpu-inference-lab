#!/usr/bin/env bash

verify_cluster_connectivity() {
  kubectl cluster-info >/dev/null 2>&1
}

ensure_namespace() {
  local namespace=$1

  if namespace_exists "${namespace}"; then
    return 0
  fi

  log "creating namespace: ${namespace}"
  kubectl create namespace "${namespace}" >/dev/null
}

kubectl_name_count() {
  local resource_kind=$1
  local resource_namespace=${2:-}
  local selector=${3:-}
  local all_namespaces=${4:-0}
  local args=("get" "${resource_kind}" "-o" "name")

  if [[ "${all_namespaces}" == "1" ]]; then
    args+=("-A")
  elif [[ -n "${resource_namespace}" ]]; then
    args+=("-n" "${resource_namespace}")
  fi

  if [[ -n "${selector}" ]]; then
    args+=("-l" "${selector}")
  fi

  kubectl "${args[@]}" 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' '
}

ingress_hostname() {
  local ingress_name=$1
  local ingress_namespace=$2

  kubectl get ingress "${ingress_name}" -n "${ingress_namespace}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
}

resource_condition_status() {
  local resource_kind=$1
  local resource_name=$2
  local condition_type=$3
  local resource_namespace=${4:-}

  if [[ -n "${resource_namespace}" ]]; then
    kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" \
      -o jsonpath="{.status.conditions[?(@.type=='${condition_type}')].status}" 2>/dev/null || true
    return 0
  fi

  kubectl get "${resource_kind}" "${resource_name}" \
    -o jsonpath="{.status.conditions[?(@.type=='${condition_type}')].status}" 2>/dev/null || true
}

resource_condition_is_status() {
  local resource_kind=$1
  local resource_name=$2
  local condition_type=$3
  local expected_status=${4:-True}
  local resource_namespace=${5:-}
  local actual_status

  actual_status=$(resource_condition_status "${resource_kind}" "${resource_name}" "${condition_type}" "${resource_namespace}")
  [[ "${actual_status}" == "${expected_status}" ]]
}

wait_for_status_condition() {
  local resource_kind=$1
  local resource_name=$2
  local condition_type=$3
  local expected_status=${4:-True}
  local timeout_seconds=${5:-300}
  local resource_namespace=${6:-}
  local start_time
  local condition_status

  start_time=$(date +%s)

  while true; do
    if [[ -n "${resource_namespace}" ]]; then
      condition_status=$(kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" \
        -o jsonpath="{.status.conditions[?(@.type=='${condition_type}')].status}" 2>/dev/null || true)
    else
      condition_status=$(kubectl get "${resource_kind}" "${resource_name}" \
        -o jsonpath="{.status.conditions[?(@.type=='${condition_type}')].status}" 2>/dev/null || true)
    fi

    if [[ "${condition_status}" == "${expected_status}" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for ${resource_kind}/${resource_name} condition ${condition_type}=${expected_status}"
      if [[ -n "${resource_namespace}" ]]; then
        kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" -o yaml >&2 || true
      else
        kubectl get "${resource_kind}" "${resource_name}" -o yaml >&2 || true
      fi
      return 1
    fi

    sleep 5
  done
}

wait_for_apiservice_available() {
  local apiservice_name=$1
  local timeout_seconds=${2:-300}
  local start_time
  local available_status

  start_time=$(date +%s)

  while true; do
    available_status=$(kubectl get apiservice "${apiservice_name}" \
      -o jsonpath="{.status.conditions[?(@.type=='Available')].status}" 2>/dev/null || true)

    if [[ "${available_status}" == "True" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for APIService ${apiservice_name} to become available"
      kubectl get apiservice "${apiservice_name}" -o yaml >&2 || true
      return 1
    fi

    sleep 5
  done
}
