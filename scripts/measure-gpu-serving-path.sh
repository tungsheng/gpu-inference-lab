#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-paths.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-common.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/kube.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-wait.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-report.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="measure-gpu-serving-path"

# Runtime configuration.
APP_NAMESPACE=${APP_NAMESPACE:-app}
KARPENTER_NAMESPACE=${KARPENTER_NAMESPACE:-karpenter}
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-${GPU_INFERENCE_DEPLOYMENT_NAME}}
NODEPOOL_NAME=${NODEPOOL_NAME:-${KARPENTER_NODEPOOL_NAME}}
NODECLASS_NAME=${NODECLASS_NAME:-${KARPENTER_NODECLASS_NAME}}
LOAD_TEST_JOB_NAME=${LOAD_TEST_JOB_NAME:-${GPU_LOAD_TEST_JOB_NAME}}
POLL_INTERVAL_SECONDS=${POLL_INTERVAL_SECONDS:-2}
PROGRESS_LOG_INTERVAL_SECONDS=${PROGRESS_LOG_INTERVAL_SECONDS:-10}
STATE_REFRESH_INTERVAL_SECONDS=${STATE_REFRESH_INTERVAL_SECONDS:-4}
API_HEALTHCHECK_INTERVAL_SECONDS=${API_HEALTHCHECK_INTERVAL_SECONDS:-15}
SPINNER_INTERVAL_TENTHS=${SPINNER_INTERVAL_TENTHS:-1}
WAIT_TIMEOUT_QUICK_SECONDS=${WAIT_TIMEOUT_QUICK_SECONDS:-300}
WAIT_TIMEOUT_STANDARD_SECONDS=${WAIT_TIMEOUT_STANDARD_SECONDS:-480}
WAIT_TIMEOUT_SCALE_SECONDS=${WAIT_TIMEOUT_SCALE_SECONDS:-720}
WAIT_TIMEOUT_SCALE_DOWN_SECONDS=${WAIT_TIMEOUT_SCALE_DOWN_SECONDS:-900}
DISABLE_SPINNER=${DISABLE_SPINNER:-0}
REPORT_PATH=""
REPORT_PATH_DEFAULT="/tmp/gpu-serving-report-$(date +%Y%m%d-%H%M%S).md"

SPINNER_FRAMES=("/" "-" "\\" "|")
TOTAL_STAGES=8
LAST_PROGRESS_LOG_AT=0
WAIT_PROGRESS_FILE=""
WAIT_SPINNER_PID=""
first_gpu_node_name=""
second_gpu_node_name=""
CURRENT_MEASUREMENT_CACHE_KEY=""
MEASUREMENT_STATE_REFRESHED_AT=""
STATE_GPU_NODE_LINES=""
STATE_GPU_NODE_NAMES=""
STATE_GPU_NODE_COUNT="0"
STATE_NODECLAIM_COUNT="0"
STATE_DEPLOYMENT_READY_REPLICAS=""
STATE_DEPLOYMENT_DESIRED_REPLICAS=""
STATE_HPA_CURRENT_REPLICAS=""
STATE_HPA_DESIRED_REPLICAS=""
STATE_FIRST_POD_NAME=""
STATE_FIRST_POD_PHASE=""
STATE_FIRST_POD_NODE_NAME=""
STATE_FIRST_POD_WAITING_REASON=""
STATE_FIRST_POD_TERMINATED_REASON=""
STATE_FIRST_POD_SCHEDULING_REASON=""
STATE_LOAD_TEST_EXISTS="0"
STATE_LOAD_TEST_ACTIVE=""
STATE_LOAD_TEST_SUCCEEDED=""
STATE_LOAD_TEST_FAILED=""
STATE_LOAD_TEST_POD_NAME=""
STATE_LOAD_TEST_POD_PHASE=""
STATE_LOAD_TEST_POD_REASON=""
STATE_NVIDIA_READY_COUNT=""
STATE_NVIDIA_DESIRED_COUNT=""

# Timeline checkpoints recorded for the report.
EVENT_NAMES=(
  start_time
  first_pod_seen
  first_nodeclaim_seen
  first_gpu_node_seen
  first_gpu_allocatable_seen
  first_ready_seen
  load_test_applied
  hpa_scale_out_seen
  second_nodeclaim_seen
  second_gpu_node_seen
  second_ready_seen
  load_test_deleted
  scale_in_ready_seen
  scale_in_node_seen
  inference_deleted
  all_gpu_nodes_removed
)
TIMELINE_EVENT_LABELS=(
  "Inference manifest applied"
  "First serving pod created"
  "First NodeClaim observed"
  "First GPU node observed"
  "GPU allocatable advertised on first node"
  "First serving pod Ready"
  "Load test applied"
  "HPA desired replicas reached 2"
  "Second NodeClaim observed"
  "Second GPU node observed"
  "Two serving replicas Ready"
  "Load test removed"
  "Deployment scaled back to one Ready replica"
  "Extra GPU node removed"
  "Inference manifest deleted"
  "All GPU nodes removed"
)

# Shared globals are consumed by sourced measurement libraries.
: "${SPINNER_FRAMES[*]}" "${WAIT_PROGRESS_FILE}" "${WAIT_SPINNER_PID}"
: "${EVENT_NAMES[*]}" "${TIMELINE_EVENT_LABELS[*]}" "${LAST_PROGRESS_LOG_AT}"

require_command kubectl

usage() {
  cat <<EOF
Usage:
  ./scripts/measure-gpu-serving-path.sh [options] [report-path]

Options:
  --report <path>            Write the Markdown report to a specific path
  --namespace <name>         Application namespace (default: ${APP_NAMESPACE})
  --deployment <name>        Inference deployment name (default: ${DEPLOYMENT_NAME})
  --nodepool <name>          Karpenter NodePool name (default: ${NODEPOOL_NAME})
  --nodeclass <name>         Karpenter EC2NodeClass name (default: ${NODECLASS_NAME})
  --poll-interval <seconds>  Polling interval in seconds (default: ${POLL_INTERVAL_SECONDS})
  --no-spinner               Disable the interactive spinner even on a TTY
  -h, --help                 Show this help

Examples:
  ./scripts/measure-gpu-serving-path.sh
  ./scripts/measure-gpu-serving-path.sh --report docs/reports/latest.md
  ./scripts/measure-gpu-serving-path.sh --poll-interval 5 docs/reports/latest.md
EOF
}

parse_args() {
  local report_override=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --report)
        report_override=${2:-}
        shift 2
        ;;
      --namespace)
        APP_NAMESPACE=${2:-}
        shift 2
        ;;
      --deployment)
        DEPLOYMENT_NAME=${2:-}
        shift 2
        ;;
      --nodepool)
        NODEPOOL_NAME=${2:-}
        shift 2
        ;;
      --nodeclass)
        NODECLASS_NAME=${2:-}
        shift 2
        ;;
      --poll-interval)
        POLL_INTERVAL_SECONDS=${2:-}
        shift 2
        ;;
      --no-spinner)
        DISABLE_SPINNER=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        log_error "unknown option: $1"
        usage >&2
        exit 1
        ;;
      *)
        if [[ -n "${report_override}" ]]; then
          log_error "report path was provided twice"
          usage >&2
          exit 1
        fi
        report_override=$1
        shift
        ;;
    esac
  done

  if [[ $# -gt 0 ]]; then
    log_error "unexpected extra arguments: $*"
    usage >&2
    exit 1
  fi

  REPORT_PATH=${report_override:-${REPORT_PATH_DEFAULT}}
}

trim_spaces() {
  local text=$1

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "${text}"
}

log_stage() {
  local stage_number=$1
  local stage_name=$2

  log_section "stage ${stage_number}/${TOTAL_STAGES}: ${stage_name}"
}

mark_measurement_state_stale() {
  MEASUREMENT_STATE_REFRESHED_AT=""
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

  deployment_fields=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}{"|"}{.spec.replicas}' 2>/dev/null || true)
  IFS='|' read -r STATE_DEPLOYMENT_READY_REPLICAS STATE_DEPLOYMENT_DESIRED_REPLICAS <<<"${deployment_fields}"

  hpa_fields=$(kubectl get hpa "${DEPLOYMENT_NAME}" -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.currentReplicas}{"|"}{.status.desiredReplicas}' 2>/dev/null || true)
  IFS='|' read -r STATE_HPA_CURRENT_REPLICAS STATE_HPA_DESIRED_REPLICAS <<<"${hpa_fields}"

  pod_fields=$(kubectl get pods -n "${APP_NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" \
    -o jsonpath='{.items[0].metadata.name}{"|"}{.items[0].status.phase}{"|"}{.items[0].spec.nodeName}{"|"}{.items[0].status.containerStatuses[0].state.waiting.reason}{"|"}{.items[0].status.containerStatuses[0].state.terminated.reason}{"|"}{.items[0].status.conditions[?(@.type=="PodScheduled")].reason}' 2>/dev/null || true)
  IFS='|' read -r STATE_FIRST_POD_NAME STATE_FIRST_POD_PHASE STATE_FIRST_POD_NODE_NAME STATE_FIRST_POD_WAITING_REASON STATE_FIRST_POD_TERMINATED_REASON STATE_FIRST_POD_SCHEDULING_REASON <<<"${pod_fields}"

  STATE_NODECLAIM_COUNT=$(kubectl_name_count nodeclaims "" "karpenter.sh/nodepool=${NODEPOOL_NAME}")

  STATE_GPU_NODE_LINES=$(kubectl get nodes -l "karpenter.sh/nodepool=${NODEPOOL_NAME}" \
    -o go-template='{{range .items}}{{.metadata.name}}{{"|" }}{{index .status.allocatable "nvidia.com/gpu"}}{{"\n"}}{{end}}' 2>/dev/null || true)
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
  local cache_key=${CURRENT_MEASUREMENT_CACHE_KEY:-$(now_epoch)}

  if [[ "${MEASUREMENT_STATE_REFRESHED_AT:-}" == "${cache_key}" ]]; then
    return 0
  fi

  refresh_measurement_state "${cache_key}"
}

verify_prerequisites() {
  local missing=()
  local current_context

  if ! verify_cluster_connectivity; then
    current_context=$(kubectl config current-context 2>/dev/null || printf 'unknown')
    log_error "unable to reach the Kubernetes API using kubectl context: ${current_context}"
    log_error "check cluster DNS/network access, confirm kubectl is pointed at the intended cluster, or refresh kubeconfig with ./scripts/apply-dev.sh."
    exit 1
  fi

  if ! resource_exists deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" kube-system; then
    missing+=("${METRICS_SERVER_DEPLOYMENT_NAME} deployment in kube-system")
  fi

  if ! namespace_exists "${KARPENTER_NAMESPACE}"; then
    missing+=("${KARPENTER_NAMESPACE} namespace")
  fi

  if ! crd_exists "nodepools.karpenter.sh"; then
    missing+=("Karpenter NodePool CRD")
  fi

  if ! crd_exists "nodeclaims.karpenter.sh"; then
    missing+=("Karpenter NodeClaim CRD")
  fi

  if ! crd_exists "ec2nodeclasses.karpenter.k8s.aws"; then
    missing+=("Karpenter EC2NodeClass CRD")
  fi

  if ! resource_exists deployment "${KARPENTER_RELEASE_NAME}" "${KARPENTER_NAMESPACE}"; then
    missing+=("${KARPENTER_RELEASE_NAME} deployment in ${KARPENTER_NAMESPACE}")
  fi

  if crd_exists "nodepools.karpenter.sh" && ! resource_exists nodepool "${NODEPOOL_NAME}"; then
    missing+=("Karpenter NodePool ${NODEPOOL_NAME}")
  fi

  if crd_exists "ec2nodeclasses.karpenter.k8s.aws" && ! resource_exists ec2nodeclass "${NODECLASS_NAME}"; then
    missing+=("Karpenter EC2NodeClass ${NODECLASS_NAME}")
  fi

  if ! resource_exists daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" kube-system; then
    missing+=("${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME} daemonset")
  fi

  if (( ${#missing[@]} > 0 )); then
    local missing_item
    log_error "dynamic GPU serving prerequisites are missing"
    for missing_item in "${missing[@]}"; do
      log_error "missing prerequisite: ${missing_item}"
    done
    log_error "this cluster is not fully post-applied for the dynamic GPU path"
    log_error "re-run ./scripts/apply-dev.sh and capture the first 'post-terraform-apply failed ... during step: ...' block, or verify kubectl is pointed at the intended cluster"
    exit 1
  fi
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
    printf '%s\n' "pod none"
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
    printf '%s\n' "load idle"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_FAILED}" && "${STATE_LOAD_TEST_FAILED}" != "0" ]]; then
    printf 'load failed(%s)\n' "${STATE_LOAD_TEST_FAILED}"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_ACTIVE}" && "${STATE_LOAD_TEST_ACTIVE}" != "0" ]]; then
    printf '%s\n' "load running"
    return 0
  fi

  if [[ -n "${STATE_LOAD_TEST_SUCCEEDED}" && "${STATE_LOAD_TEST_SUCCEEDED}" != "0" ]]; then
    printf '%s\n' "load done"
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

  printf '%s | ready %s/%s | gpu %s' \
    "${pod_summary:-pod none}" "${ready_replicas:-0}" "${desired_replicas:-0}" "${gpu_nodes:-0}"

  if [[ "${nodeclaims:-0}" != "0" ]]; then
    printf ' | claims %s' "${nodeclaims:-0}"
  fi

  if [[ -n "${hpa_current}" || -n "${hpa_desired}" ]]; then
    printf ' | hpa %s/%s' "${hpa_current:-0}" "${hpa_desired:-0}"
  fi

  printf '\n'
}

serving_and_load_state_snapshot() {
  printf '%s | %s\n' "$(serving_state_snapshot)" "$(load_test_job_summary)"
}

first_gpu_capacity_snapshot() {
  local current_node_name
  local allocatable_gpu

  current_node_name=$(resolve_gpu_node_name "${first_gpu_node_name:-}")
  allocatable_gpu=$(node_allocatable_gpu "${current_node_name}")
  printf 'node %s | alloc %s | plugin %s | %s\n' \
    "${current_node_name:-pending}" "${allocatable_gpu:-0}" "$(nvidia_daemonset_status_summary)" "$(serving_state_snapshot)"
}

second_gpu_capacity_snapshot() {
  local current_node_name
  local allocatable_gpu

  current_node_name=$(resolve_gpu_node_name "${second_gpu_node_name:-}" "${first_gpu_node_name:-}")
  allocatable_gpu=$(node_allocatable_gpu "${current_node_name}")
  printf 'node %s | alloc %s | plugin %s | %s\n' \
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
  local gpu_count

  if [[ -z "${node_name}" ]]; then
    return 0
  fi

  ensure_measurement_state_current

  while IFS= read -r node_line; do
    [[ -z "${node_line}" ]] && continue
    if [[ "${node_line%%|*}" == "${node_name}" ]]; then
      gpu_count=${node_line#*|}
      gpu_count=$(trim_spaces "${gpu_count}")
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
  kubectl get nodes -l "karpenter.sh/nodepool=${NODEPOOL_NAME}" -o wide >&2 || true
}

describe_first_gpu_timeout_context() {
  describe_gpu_node_timeout_context "${first_gpu_node_name:-}"
}

describe_second_gpu_timeout_context() {
  describe_gpu_node_timeout_context "${second_gpu_node_name:-}" "${first_gpu_node_name:-}"
}

cleanup_existing_workloads() {
  log_stage 1 "clean up previous GPU measurement resources"
  delete_manifest_quiet "${GPU_SMOKE_TEST_MANIFEST}"
  delete_manifest_quiet "${GPU_LOAD_TEST_MANIFEST}"
  delete_manifest_quiet "${GPU_INFERENCE_MANIFEST}"

  wait_for_numeric_at_most "GPU nodes to scale back to zero before starting a fresh run" "${WAIT_TIMEOUT_STANDARD_SECONDS}" 0 gpu_node_count serving_state_snapshot >/dev/null
}

cleanup_on_exit() {
  local exit_code=$?

  trap - EXIT

  if (( exit_code == 0 )); then
    return 0
  fi

  stop_wait_progress
  LAST_PROGRESS_LOG_AT=0
  log_warn "run failed; deleting load-test and inference workloads to avoid leaving GPU nodes behind"
  delete_manifest_quiet "${GPU_LOAD_TEST_MANIFEST}"
  delete_manifest_quiet "${GPU_INFERENCE_MANIFEST}"
  wait_for_numeric_at_most "GPU nodes to scale back to zero during cleanup" "${WAIT_TIMEOUT_STANDARD_SECONDS}" 0 gpu_node_count serving_state_snapshot >/dev/null || true

  exit "${exit_code}"
}

trap cleanup_on_exit EXIT

prepare_measurement_run() {
  cleanup_existing_workloads

  log_stage 2 "verify cluster prerequisites for the dynamic GPU path"
  verify_prerequisites
  ensure_namespace "${APP_NAMESPACE}"
  record_event start_time
}

measure_first_cold_start() {
  log_stage 3 "apply the GPU inference deployment and measure the first cold start"
  apply_manifest_quiet "${GPU_INFERENCE_MANIFEST}"

  log "waiting for the first serving pod object to appear"
  wait_for_value "the first serving pod to be created" "${WAIT_TIMEOUT_QUICK_SECONDS}" first_pod_name serving_state_snapshot fatal_serving_state >/dev/null
  record_event first_pod_seen

  log "waiting for Karpenter to create the first NodeClaim"
  wait_for_numeric_at_least "the first NodeClaim" "${WAIT_TIMEOUT_QUICK_SECONDS}" 1 nodeclaim_count serving_state_snapshot fatal_serving_state >/dev/null
  record_event first_nodeclaim_seen

  log "waiting for the first GPU worker node to register with the cluster"
  wait_for_numeric_at_least "the first GPU node" "${WAIT_TIMEOUT_SCALE_SECONDS}" 1 gpu_node_count serving_state_snapshot fatal_serving_state >/dev/null
  record_event first_gpu_node_seen
  first_gpu_node_name=$(find_gpu_node_name)

  log "waiting for NVIDIA device capacity on node ${first_gpu_node_name}"
  wait_for_gpu_allocatable \
    "nvidia.com/gpu allocatable on the first GPU node" \
    "${WAIT_TIMEOUT_STANDARD_SECONDS}" \
    first_gpu_node_allocatable \
    first_gpu_capacity_snapshot \
    fatal_serving_state \
    describe_first_gpu_timeout_context >/dev/null
  record_event first_gpu_allocatable_seen

  log "waiting for the first vLLM replica to become Ready"
  wait_for_numeric_at_least "the first Ready serving replica" "${WAIT_TIMEOUT_SCALE_SECONDS}" 1 deployment_ready_replicas serving_state_snapshot fatal_serving_state >/dev/null
  record_event first_ready_seen
}

confirm_steady_state_before_scale_out() {
  log_stage 4 "confirm the inference service is steady before scale-out"
  log "waiting for the HPA to settle at one desired replica before applying load"
  wait_for_numeric_at_least "the HPA to report a desired replica count" "${WAIT_TIMEOUT_STANDARD_SECONDS}" 1 hpa_desired_replicas serving_state_snapshot fatal_serving_state >/dev/null
  wait_for_numeric_at_most "the HPA to remain at one desired replica before load starts" "${WAIT_TIMEOUT_STANDARD_SECONDS}" 1 hpa_desired_replicas serving_state_snapshot fatal_serving_state >/dev/null
}

measure_scale_out_under_load() {
  log_stage 5 "apply synthetic load to trigger HPA-driven GPU scale-out"
  apply_manifest_quiet "${GPU_LOAD_TEST_MANIFEST}"
  record_event load_test_applied

  log "waiting for the HPA to request a second replica"
  wait_for_numeric_at_least "the HPA desired replica count to reach 2" "${WAIT_TIMEOUT_SCALE_SECONDS}" 2 hpa_desired_replicas serving_and_load_state_snapshot fatal_scale_out_state >/dev/null
  record_event hpa_scale_out_seen

  log "waiting for Karpenter to create a second NodeClaim"
  wait_for_numeric_at_least "the second NodeClaim" "${WAIT_TIMEOUT_SCALE_SECONDS}" 2 nodeclaim_count serving_and_load_state_snapshot fatal_scale_out_state >/dev/null
  record_event second_nodeclaim_seen

  log "waiting for the second GPU worker node to join"
  wait_for_numeric_at_least "the second GPU node" "${WAIT_TIMEOUT_SCALE_SECONDS}" 2 gpu_node_count serving_and_load_state_snapshot fatal_scale_out_state >/dev/null
  record_event second_gpu_node_seen
  second_gpu_node_name=$(find_gpu_node_name "${first_gpu_node_name:-}")

  log "waiting for NVIDIA device capacity on node ${second_gpu_node_name}"
  wait_for_gpu_allocatable \
    "nvidia.com/gpu allocatable on the second GPU node" \
    "${WAIT_TIMEOUT_STANDARD_SECONDS}" \
    second_gpu_node_allocatable \
    second_gpu_capacity_snapshot \
    fatal_scale_out_state \
    describe_second_gpu_timeout_context >/dev/null

  log "waiting for both vLLM replicas to become Ready"
  wait_for_numeric_at_least "two Ready serving replicas" "${WAIT_TIMEOUT_SCALE_SECONDS}" 2 deployment_ready_replicas serving_and_load_state_snapshot fatal_scale_out_state >/dev/null
  record_event second_ready_seen
}

measure_partial_scale_down() {
  log_stage 6 "remove load and validate partial scale-down"
  delete_manifest_quiet "${GPU_LOAD_TEST_MANIFEST}"
  record_event load_test_deleted

  log "waiting for the deployment to settle back to one Ready replica"
  wait_for_numeric_at_most "the deployment to settle back to one Ready replica" "${WAIT_TIMEOUT_SCALE_DOWN_SECONDS}" 1 deployment_ready_replicas serving_state_snapshot fatal_serving_state >/dev/null
  record_event scale_in_ready_seen

  log "waiting for the extra GPU node to terminate after consolidation"
  wait_for_numeric_at_most "the extra GPU node to terminate" "${WAIT_TIMEOUT_SCALE_DOWN_SECONDS}" 1 gpu_node_count serving_state_snapshot fatal_serving_state >/dev/null
  record_event scale_in_node_seen
}

measure_full_scale_down() {
  log_stage 7 "delete the inference workload and validate full GPU scale-down"
  delete_manifest_quiet "${GPU_INFERENCE_MANIFEST}"
  record_event inference_deleted

  log "waiting for all Karpenter GPU nodes to disappear"
  wait_for_numeric_at_most "all GPU nodes to scale back to zero" "${WAIT_TIMEOUT_SCALE_DOWN_SECONDS}" 0 gpu_node_count serving_state_snapshot >/dev/null
  record_event all_gpu_nodes_removed
}

write_measurement_report_stage() {
  log_stage 8 "write the measurement report"
  render_report
  log_success "report written to ${REPORT_PATH}"
}

main() {
  parse_args "$@"
  initialize_event_state
  prepare_measurement_run
  measure_first_cold_start
  confirm_steady_state_before_scale_out
  measure_scale_out_under_load
  measure_partial_scale_down
  measure_full_scale_down
  write_measurement_report_stage
}

main "$@"
