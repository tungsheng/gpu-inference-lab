#!/usr/bin/env bash

MEASURE_STATE_LIB_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${MEASURE_STATE_LIB_DIR}/measure-context.sh"

trim_spaces() {
  local text=$1

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "${text}"
}

mark_measurement_state_stale() {
  MEASUREMENT_STATE_REFRESHED_AT=""
}

measurement_gpu_node_selector() {
  local selector="workload=gpu"

  if [[ -n "${MEASUREMENT_MANAGED_NODEPOOL_SELECTOR:-}" ]]; then
    printf '%s,%s\n' "${selector}" "${MEASUREMENT_MANAGED_NODEPOOL_SELECTOR}"
    return 0
  fi

  if [[ -n "${MEASUREMENT_NODEPOOL_SELECTOR:-}" ]]; then
    printf '%s,%s\n' "${selector}" "${MEASUREMENT_NODEPOOL_SELECTOR}"
    return 0
  fi

  printf '%s\n' "${selector}"
}

refresh_measurement_state() {
  local cache_key=${1:-$(now_epoch)}
  local deployment_fields
  local hpa_fields
  local pod_fields
  local node_line
  local job_fields
  local load_test_pod_fields
  local load_test_reason_fields
  local nvidia_fields

  STATE_INFERENCE_INGRESS_HOSTNAME=$(kubectl get ingress "${GPU_INFERENCE_INGRESS_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  deployment_fields=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}{"|"}{.spec.replicas}' 2>/dev/null || true)
  IFS='|' read -r STATE_DEPLOYMENT_READY_REPLICAS STATE_DEPLOYMENT_DESIRED_REPLICAS <<<"${deployment_fields}"

  hpa_fields=$(kubectl get hpa "${DEPLOYMENT_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.currentReplicas}{"|"}{.status.desiredReplicas}' 2>/dev/null || true)
  IFS='|' read -r STATE_HPA_CURRENT_REPLICAS STATE_HPA_DESIRED_REPLICAS <<<"${hpa_fields}"

  pod_fields=$(kubectl get pods -n "${APP_NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" \
    -o jsonpath='{.items[0].metadata.name}{"|"}{.items[0].status.phase}{"|"}{.items[0].spec.nodeName}{"|"}{.items[0].status.containerStatuses[0].state.waiting.reason}{"|"}{.items[0].status.containerStatuses[0].state.terminated.reason}{"|"}{.items[0].status.conditions[?(@.type=="PodScheduled")].reason}' 2>/dev/null || true)
  IFS='|' read -r STATE_FIRST_POD_NAME STATE_FIRST_POD_PHASE STATE_FIRST_POD_NODE_NAME STATE_FIRST_POD_WAITING_REASON STATE_FIRST_POD_TERMINATED_REASON STATE_FIRST_POD_SCHEDULING_REASON <<<"${pod_fields}"

  STATE_NODECLAIM_COUNT=$(kubectl_name_count nodeclaims "" "${MEASUREMENT_NODEPOOL_SELECTOR}")

  STATE_GPU_NODE_LINES=$(kubectl get nodes -l "$(measurement_gpu_node_selector)" \
    -o go-template='{{range .items}}{{.metadata.name}}{{"|" }}{{index .status.allocatable "nvidia.com/gpu"}}{{"|" }}{{index .metadata.labels "node.kubernetes.io/instance-type"}}{{"\n"}}{{end}}' 2>/dev/null || true)
  STATE_GPU_NODE_NAMES=""
  while IFS= read -r node_line; do
    [[ -z "${node_line}" ]] && continue
    STATE_GPU_NODE_NAMES+="${node_line%%|*}"$'\n'
  done <<<"${STATE_GPU_NODE_LINES}"
  STATE_GPU_NODE_COUNT=$(printf '%s' "${STATE_GPU_NODE_NAMES}" | sed '/^$/d' | wc -l | tr -d ' ')

  job_fields=$(kubectl get job "${LOAD_TEST_JOB_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.active}{"|"}{.status.succeeded}{"|"}{.status.failed}' 2>/dev/null || true)
  if [[ -n "${job_fields}" ]]; then
    STATE_LOAD_TEST_EXISTS="1"
    IFS='|' read -r STATE_LOAD_TEST_ACTIVE STATE_LOAD_TEST_SUCCEEDED STATE_LOAD_TEST_FAILED <<<"${job_fields}"
    load_test_pod_fields=$(kubectl get pods -n "${APP_NAMESPACE}" -l "job-name=${LOAD_TEST_JOB_NAME}" \
      -o jsonpath='{.items[0].metadata.name}{"|"}{.items[0].status.phase}' 2>/dev/null || true)
    IFS='|' read -r STATE_LOAD_TEST_POD_NAME STATE_LOAD_TEST_POD_PHASE <<<"${load_test_pod_fields}"
    load_test_reason_fields=$(kubectl get pod "${STATE_LOAD_TEST_POD_NAME}" -n "${APP_NAMESPACE}" \
      -o jsonpath='{range .status.containerStatuses[*]}{.state.waiting.reason}{" "}{.state.terminated.reason}{" "}{end}' 2>/dev/null || true)
    STATE_LOAD_TEST_POD_REASON=$(awk '{print $1}' <<<"${load_test_reason_fields}")
  else
    STATE_LOAD_TEST_EXISTS="0"
    STATE_LOAD_TEST_ACTIVE=""
    STATE_LOAD_TEST_SUCCEEDED=""
    STATE_LOAD_TEST_FAILED=""
    STATE_LOAD_TEST_POD_NAME=""
    STATE_LOAD_TEST_POD_PHASE=""
    STATE_LOAD_TEST_POD_REASON=""
  fi

  nvidia_fields=$(kubectl get daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" -n kube-system \
    -o jsonpath='{.status.numberReady}{"|"}{.status.desiredNumberScheduled}' 2>/dev/null || true)
  IFS='|' read -r STATE_NVIDIA_READY_COUNT STATE_NVIDIA_DESIRED_COUNT <<<"${nvidia_fields}"

  MEASUREMENT_STATE_REFRESHED_AT="${cache_key}"
}

ensure_measurement_state_current() {
  local cache_key

  cache_key=$(measurement_state_cache_key)
  if [[ -z "${cache_key}" ]]; then
    cache_key=$(now_epoch)
  fi

  if [[ "${MEASUREMENT_STATE_REFRESHED_AT:-}" == "${cache_key}" ]]; then
    return 0
  fi

  refresh_measurement_state "${cache_key}"
}

apply_manifest_quiet() {
  local manifest_path=$1

  kubectl apply -f "${manifest_path}" >/dev/null
  mark_measurement_state_stale
}

delete_manifest_quiet() {
  local manifest_path=$1

  kubectl delete -f "${manifest_path}" --ignore-not-found=true >/dev/null 2>&1 || true
  mark_measurement_state_stale
}

inference_ingress_hostname() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_INFERENCE_INGRESS_HOSTNAME}"
}

inference_edge_url() {
  local hostname

  hostname=$(inference_ingress_hostname)
  if [[ -z "${hostname}" ]]; then
    return 0
  fi

  printf 'http://%s%s\n' "${hostname}" "${GPU_INFERENCE_EDGE_PATH}"
}

gpu_node_names() {
  ensure_measurement_state_current
  printf '%s' "${STATE_GPU_NODE_NAMES}"
}

find_gpu_node_name() {
  local excluded_node_name=${1:-}
  local node_name

  while IFS= read -r node_name; do
    if [[ -z "${node_name}" ]]; then
      continue
    fi

    if [[ -n "${excluded_node_name}" && "${node_name}" == "${excluded_node_name}" ]]; then
      continue
    fi

    printf '%s\n' "${node_name}"
    return 0
  done < <(gpu_node_names)

  return 0
}

resolve_gpu_node_name() {
  local preferred_node_name=${1:-}
  local excluded_node_name=${2:-}

  if [[ -n "${preferred_node_name}" ]] && resource_exists node "${preferred_node_name}"; then
    printf '%s\n' "${preferred_node_name}"
    return 0
  fi

  find_gpu_node_name "${excluded_node_name}"
  return 0
}

gpu_node_count() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_GPU_NODE_COUNT:-0}"
}

nodeclaim_count() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_NODECLAIM_COUNT:-0}"
}

deployment_ready_replicas() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_DEPLOYMENT_READY_REPLICAS}"
}

deployment_desired_replicas() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_DEPLOYMENT_DESIRED_REPLICAS}"
}

hpa_desired_replicas() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_HPA_DESIRED_REPLICAS}"
}

hpa_current_replicas() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_HPA_CURRENT_REPLICAS}"
}

first_pod_status_fields() {
  ensure_measurement_state_current
  printf '%s|%s|%s|%s|%s|%s\n' \
    "${STATE_FIRST_POD_NAME}" \
    "${STATE_FIRST_POD_PHASE}" \
    "${STATE_FIRST_POD_NODE_NAME}" \
    "${STATE_FIRST_POD_WAITING_REASON}" \
    "${STATE_FIRST_POD_TERMINATED_REASON}" \
    "${STATE_FIRST_POD_SCHEDULING_REASON}"
}

first_pod_name() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_FIRST_POD_NAME}"
}

first_pod_status_summary() {
  local pod_fields
  local pod_name
  local pod_phase_value
  local node_name
  local waiting_reason
  local terminated_reason
  local scheduling_reason
  local pod_reason

  pod_fields=$(first_pod_status_fields)
  IFS='|' read -r pod_name pod_phase_value node_name waiting_reason terminated_reason scheduling_reason <<<"${pod_fields}"

  if [[ -z "${pod_name}" ]]; then
    printf '%s\n' "pod missing"
    return 0
  fi

  pod_reason=${waiting_reason:-${terminated_reason:-}}

  if [[ -z "${pod_reason}" && -n "${scheduling_reason}" && "${scheduling_reason}" != "Scheduled" ]]; then
    pod_reason=${scheduling_reason}
  fi

  printf 'pod %s' "${pod_phase_value:-unknown}"

  if [[ -n "${pod_reason}" ]]; then
    printf ' (%s)' "${pod_reason}"
  fi

  if [[ -n "${node_name}" ]]; then
    printf ' on %s' "${node_name}"
  fi

  printf '\n'
}

load_test_job_summary() {
  ensure_measurement_state_current

  if [[ "${STATE_LOAD_TEST_EXISTS}" != "1" ]]; then
    printf '%s\n' "load missing"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_FAILED}" && "${STATE_LOAD_TEST_FAILED}" != "0" ]]; then
    printf 'load failed (%s)\n' "${STATE_LOAD_TEST_FAILED}"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_ACTIVE}" && "${STATE_LOAD_TEST_ACTIVE}" != "0" ]]; then
    printf '%s\n' "load running"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_SUCCEEDED}" && "${STATE_LOAD_TEST_SUCCEEDED}" != "0" ]]; then
    printf '%s\n' "load complete"
    return 0
  fi

  printf '%s\n' "load pending"
}

nvidia_daemonset_status_summary() {
  ensure_measurement_state_current
  printf '%s\n' "${STATE_NVIDIA_READY_COUNT:-0}/${STATE_NVIDIA_DESIRED_COUNT:-0}"
}

serving_state_snapshot() {
  local ready_replicas
  local desired_replicas
  local hpa_current
  local hpa_desired
  local nodeclaims
  local gpu_nodes
  local pod_summary

  ready_replicas=$(deployment_ready_replicas)
  desired_replicas=$(deployment_desired_replicas)
  hpa_current=$(hpa_current_replicas)
  hpa_desired=$(hpa_desired_replicas)
  nodeclaims=$(nodeclaim_count)
  gpu_nodes=$(gpu_node_count)
  pod_summary=$(first_pod_status_summary)

  printf '%s | replicas ready %s/%s | gpu nodes %s' \
    "${pod_summary:-pod missing}" "${ready_replicas:-0}" "${desired_replicas:-0}" "${gpu_nodes:-0}"

  if [[ "${nodeclaims:-0}" != "0" ]]; then
    printf ' | nodeclaims %s' "${nodeclaims:-0}"
  fi

  if [[ -n "${hpa_current}" || -n "${hpa_desired}" ]]; then
    printf ' | hpa current/desired %s/%s' "${hpa_current:-0}" "${hpa_desired:-0}"
  fi

  printf '\n'
}

serving_and_load_state_snapshot() {
  printf '%s | %s\n' "$(serving_state_snapshot)" "$(load_test_job_summary)"
}

edge_state_snapshot() {
  local target_url

  target_url=$(inference_edge_url)
  if [[ -n "${target_url}" ]]; then
    printf 'edge %s | %s\n' "${target_url}" "$(serving_state_snapshot)"
    return 0
  fi

  printf 'edge unavailable | %s\n' "$(serving_state_snapshot)"
}

first_gpu_capacity_snapshot() {
  local current_node_name
  local allocatable_gpu

  current_node_name=$(resolve_gpu_node_name "${first_gpu_node_name:-}")
  allocatable_gpu=$(node_allocatable_gpu "${current_node_name}")
  printf 'node %s | gpu allocatable %s | device plugin %s | %s\n' \
    "${current_node_name:-pending}" "${allocatable_gpu:-0}" "$(nvidia_daemonset_status_summary)" "$(serving_state_snapshot)"
}

second_gpu_capacity_snapshot() {
  local current_node_name
  local allocatable_gpu

  current_node_name=$(resolve_gpu_node_name "${second_gpu_node_name:-}" "${first_gpu_node_name:-}")
  allocatable_gpu=$(node_allocatable_gpu "${current_node_name}")
  printf 'node %s | gpu allocatable %s | device plugin %s | %s\n' \
    "${current_node_name:-pending}" "${allocatable_gpu:-0}" "$(nvidia_daemonset_status_summary)" "$(serving_and_load_state_snapshot)"
}

fatal_serving_state() {
  local pod_fields
  local pod_name
  local pod_phase_value
  local node_name
  local waiting_reason
  local terminated_reason
  local scheduling_reason
  local pod_reason

  pod_fields=$(first_pod_status_fields)
  IFS='|' read -r pod_name pod_phase_value node_name waiting_reason terminated_reason scheduling_reason <<<"${pod_fields}"

  if [[ -z "${pod_name}" ]]; then
    return 0
  fi

  pod_reason=${waiting_reason:-${terminated_reason:-}}

  if [[ -z "${pod_reason}" && -n "${scheduling_reason}" && "${scheduling_reason}" != "Scheduled" ]]; then
    pod_reason=${scheduling_reason}
  fi

  case "${pod_reason}" in
    ImagePullBackOff|ErrImagePull|InvalidImageName|CreateContainerConfigError|CreateContainerError|CrashLoopBackOff|RunContainerError|ContainerCannotRun|OOMKilled|StartError|Error)
      printf 'serving pod %s entered %s\n' "${pod_name}" "${pod_reason}"
      return 0
      ;;
  esac

  if [[ "${pod_phase_value}" == "Failed" ]]; then
    printf 'serving pod %s entered Failed phase\n' "${pod_name}"
  fi
}

fatal_load_test_state() {
  ensure_measurement_state_current

  if [[ "${STATE_LOAD_TEST_EXISTS}" != "1" ]]; then
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_FAILED}" && "${STATE_LOAD_TEST_FAILED}" != "0" ]]; then
    printf 'load-test job %s reported %s failed pod(s)\n' "${LOAD_TEST_JOB_NAME}" "${STATE_LOAD_TEST_FAILED}"
    return 0
  fi

  if [[ -z "${STATE_LOAD_TEST_POD_NAME}" ]]; then
    return 0
  fi

  case "${STATE_LOAD_TEST_POD_REASON}" in
    ImagePullBackOff|ErrImagePull|InvalidImageName|CreateContainerConfigError|CreateContainerError|CrashLoopBackOff|RunContainerError|ContainerCannotRun|OOMKilled|StartError|Error)
      printf 'load-test pod %s entered %s\n' "${STATE_LOAD_TEST_POD_NAME}" "${STATE_LOAD_TEST_POD_REASON}"
      return 0
      ;;
  esac

  if [[ "${STATE_LOAD_TEST_POD_PHASE}" == "Failed" ]]; then
    printf 'load-test pod %s entered Failed phase\n' "${STATE_LOAD_TEST_POD_NAME}"
  fi
}

fatal_scale_out_state() {
  local failure_reason

  failure_reason=$(fatal_serving_state)
  if [[ -n "${failure_reason}" ]]; then
    printf '%s\n' "${failure_reason}"
    return 0
  fi

  fatal_load_test_state
}

node_allocatable_gpu() {
  local node_name=$1
  local node_line
  local gpu_count=""
  local instance_type=""

  if [[ -z "${node_name}" ]]; then
    return 0
  fi

  ensure_measurement_state_current

  while IFS= read -r node_line; do
    [[ -z "${node_line}" ]] && continue
    if [[ "${node_line%%|*}" == "${node_name}" ]]; then
      gpu_count=${node_line#*|}
      gpu_count=${gpu_count%%|*}
      gpu_count=$(trim_spaces "${gpu_count}")
      instance_type=${node_line##*|}
      instance_type=$(trim_spaces "${instance_type}")
      break
    fi
  done <<<"${STATE_GPU_NODE_LINES}"

  case "${gpu_count}" in
    ""|"<no value>"|"<nil>")
      gpu_count=""
      ;;
  esac

  printf '%s\n' "${gpu_count}"
}

node_instance_type() {
  local node_name=$1
  local node_line
  local instance_type=""

  if [[ -z "${node_name}" ]]; then
    return 0
  fi

  ensure_measurement_state_current

  while IFS= read -r node_line; do
    [[ -z "${node_line}" ]] && continue
    if [[ "${node_line%%|*}" == "${node_name}" ]]; then
      instance_type=${node_line##*|}
      instance_type=$(trim_spaces "${instance_type}")
      break
    fi
  done <<<"${STATE_GPU_NODE_LINES}"

  case "${instance_type}" in
    ""|"<no value>"|"<nil>")
      instance_type=""
      ;;
  esac

  printf '%s\n' "${instance_type}"
}

first_gpu_node_allocatable() {
  node_allocatable_gpu "$(resolve_gpu_node_name "${first_gpu_node_name:-}")"
}

second_gpu_node_allocatable() {
  node_allocatable_gpu "$(resolve_gpu_node_name "${second_gpu_node_name:-}" "${first_gpu_node_name:-}")"
}

describe_gpu_node_timeout_context() {
  local preferred_node_name=${1:-}
  local excluded_node_name=${2:-}
  local current_node_name

  current_node_name=$(resolve_gpu_node_name "${preferred_node_name}" "${excluded_node_name}")

  if [[ -n "${preferred_node_name}" && -n "${current_node_name}" && "${preferred_node_name}" != "${current_node_name}" ]]; then
    log_warn "tracked GPU node ${preferred_node_name} is gone; describing current GPU node ${current_node_name} instead"
  fi

  if [[ -n "${current_node_name}" ]]; then
    kubectl describe node "${current_node_name}" >&2 || true
    return 0
  fi

  log_warn "no active GPU node is available to describe"
  kubectl get nodes -l "workload=gpu" -o wide >&2 || true
}

describe_first_gpu_timeout_context() {
  describe_gpu_node_timeout_context "${first_gpu_node_name:-}"
}

describe_second_gpu_timeout_context() {
  describe_gpu_node_timeout_context "${second_gpu_node_name:-}" "${first_gpu_node_name:-}"
}
