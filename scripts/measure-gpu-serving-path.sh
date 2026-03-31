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
. "${SCRIPT_DIR}/lib/measure-context.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-wait.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-report.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-state.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/measure-runtime.sh"
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
JSON_REPORT_PATH=${JSON_REPORT_PATH:-""}
REPORT_PATH_DEFAULT="/tmp/gpu-serving-report-$(date +%Y%m%d-%H%M%S).md"

TOTAL_STAGES=8
require_command kubectl

usage() {
  cat <<EOF
Usage:
  ./scripts/measure-gpu-serving-path.sh [options] [report-path]

Options:
  --report <path>            Write the Markdown report to a specific path
  --json-report <path>       Write an additional structured JSON report
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
  ./scripts/measure-gpu-serving-path.sh --report docs/reports/latest.md --json-report docs/reports/latest.json
  ./scripts/measure-gpu-serving-path.sh --poll-interval 5 docs/reports/latest.md
EOF
}

require_option_value() {
  local option_name=$1
  local option_value=${2-}

  if [[ -z "${option_value}" || "${option_value}" == -* ]]; then
    log_error "${option_name} requires a value"
    usage >&2
    exit 1
  fi

  printf '%s\n' "${option_value}"
}

parse_args() {
  local report_override=""
  local json_report_override=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --report)
        report_override=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --json-report)
        json_report_override=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --namespace)
        APP_NAMESPACE=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --deployment)
        DEPLOYMENT_NAME=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --nodepool)
        NODEPOOL_NAME=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --nodeclass)
        NODECLASS_NAME=$(require_option_value "$1" "${2-}")
        shift 2
        ;;
      --poll-interval)
        POLL_INTERVAL_SECONDS=$(require_option_value "$1" "${2-}")
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
  JSON_REPORT_PATH=${json_report_override:-${JSON_REPORT_PATH}}
}

log_stage() {
  local stage_number=$1
  local stage_name=$2

  log_section "stage ${stage_number}/${TOTAL_STAGES}: ${stage_name}"
}

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
  log_success "Markdown report written to ${REPORT_PATH}"
  if [[ -n "${JSON_REPORT_PATH}" ]]; then
    log_success "JSON report written to ${JSON_REPORT_PATH}"
  fi
}

main() {
  parse_args "$@"
  initialize_measurement_context
  install_measurement_cleanup_trap
  initialize_event_state
  prepare_measurement_run
  measure_first_cold_start
  confirm_steady_state_before_scale_out
  measure_scale_out_under_load
  measure_partial_scale_down
  measure_full_scale_down
  write_measurement_report_stage
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
