#!/usr/bin/env bash

LOG_ICON_INFO=${LOG_ICON_INFO:-INFO}
LOG_ICON_SUCCESS=${LOG_ICON_SUCCESS:-OK}
LOG_ICON_WARN=${LOG_ICON_WARN:-WARN}
LOG_ICON_ERROR=${LOG_ICON_ERROR:-ERR}
LOG_COLOR_PREFIX=${LOG_COLOR_PREFIX:-90}
LOG_COLOR_INFO=${LOG_COLOR_INFO:-36}
LOG_COLOR_SUCCESS=${LOG_COLOR_SUCCESS:-32}
LOG_COLOR_WARN=${LOG_COLOR_WARN:-33}
LOG_COLOR_ERROR=${LOG_COLOR_ERROR:-31}

require_command() {
  local command_name=$1

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log_error "missing required command: ${command_name}"
    exit 1
  fi
}

require_commands() {
  local command_name

  for command_name in "$@"; do
    require_command "${command_name}"
  done
}

require_directory() {
  local directory_path=$1
  local label=${2:-Directory}

  if [[ ! -d "${directory_path}" ]]; then
    log_error "${label} not found: ${directory_path}"
    exit 1
  fi
}

log_with_icon() {
  local icon=$1
  local color_code=$2
  shift 2
  local prefix=${SCRIPT_NAME:-script}
  local prefix_display="[${prefix}]"
  local icon_display

  printf -v icon_display '%-4s' "${icon}"

  if color_enabled; then
    prefix_display=$(colorize_text "${LOG_COLOR_PREFIX}" "${prefix_display}")
    icon_display=$(colorize_text "${color_code}" "${icon_display}")
  fi

  printf '%s %s %s\n' "${prefix_display}" "${icon_display}" "$*" >&2
}

color_enabled() {
  [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]
}

colorize_text() {
  local color_code=$1
  local text=$2

  if ! color_enabled; then
    printf '%s' "${text}"
    return 0
  fi

  printf '\033[%sm%s\033[0m' "${color_code}" "${text}"
}

log() {
  log_with_icon "${LOG_ICON_INFO}" "${LOG_COLOR_INFO}" "$@"
}

log_success() {
  log_with_icon "${LOG_ICON_SUCCESS}" "${LOG_COLOR_SUCCESS}" "$@"
}

log_warn() {
  log_with_icon "${LOG_ICON_WARN}" "${LOG_COLOR_WARN}" "$@"
}

log_error() {
  log_with_icon "${LOG_ICON_ERROR}" "${LOG_COLOR_ERROR}" "$@"
}

log_section() {
  printf '\n' >&2
  log "$@"
}

run_step() {
  current_step=$1
  shift
  log "${current_step}"
  "$@"
  log_success "${current_step}"
}

retry_command() {
  local attempts=$1
  local delay_seconds=$2
  shift 2

  local attempt=1

  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi

    log_warn "command failed on attempt ${attempt}/${attempts}; retrying in ${delay_seconds}s: $*"
    attempt=$((attempt + 1))
    sleep "${delay_seconds}"
  done
}

namespace_exists() {
  kubectl get namespace "$1" >/dev/null 2>&1
}

resource_exists() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=${3:-}

  if [[ -n "${resource_namespace}" ]]; then
    kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" >/dev/null 2>&1
    return
  fi

  kubectl get "${resource_kind}" "${resource_name}" >/dev/null 2>&1
}

crd_exists() {
  kubectl get crd "$1" >/dev/null 2>&1
}

api_resource_exists() {
  local resource_name=$1

  if crd_exists "${resource_name}"; then
    return 0
  fi

  kubectl api-resources -o name 2>/dev/null | grep -qx "${resource_name}"
}

wait_for_crd() {
  local crd_name=$1
  local timeout_seconds=${2:-180}
  local start_time

  start_time=$(date +%s)

  while true; do
    local established_status
    established_status=$(kubectl get crd "${crd_name}" \
      -o jsonpath="{.status.conditions[?(@.type=='Established')].status}" 2>/dev/null || true)

    if [[ "${established_status}" == "True" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for CRD ${crd_name} to become established"
      kubectl get crd "${crd_name}" -o yaml >&2 || true
      return 1
    fi

    sleep 5
  done
}

wait_for_resource_deletion() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=${3:-}
  local timeout_seconds=${4:-300}
  local start_time

  start_time=$(date +%s)

  while true; do
    if ! resource_exists "${resource_kind}" "${resource_name}" "${resource_namespace}"; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for ${resource_kind}/${resource_name} deletion"
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

wait_for_resource_existence() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=${3:-}
  local timeout_seconds=${4:-300}
  local start_time

  start_time=$(date +%s)

  while true; do
    if resource_exists "${resource_kind}" "${resource_name}" "${resource_namespace}"; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for ${resource_kind}/${resource_name} to appear"
      if [[ -n "${resource_namespace}" ]]; then
        kubectl get "${resource_kind}" -n "${resource_namespace}" >&2 || true
      else
        kubectl get "${resource_kind}" >&2 || true
      fi
      return 1
    fi

    sleep 5
  done
}

wait_for_no_resources() {
  local resource_kind=$1
  local resource_namespace=${2:-}
  local selector=${3:-}
  local timeout_seconds=${4:-300}
  local all_namespaces=${5:-0}
  local start_time

  start_time=$(date +%s)

  while true; do
    local count
    local args=("get" "${resource_kind}")

    count=$(kubectl_name_count "${resource_kind}" "${resource_namespace}" "${selector}" "${all_namespaces}")

    if [[ "${count}" == "0" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for ${resource_kind} resources to disappear"
      if [[ "${all_namespaces}" == "1" ]]; then
        args+=("-A")
      elif [[ -n "${resource_namespace}" ]]; then
        args+=("-n" "${resource_namespace}")
      fi
      if [[ -n "${selector}" ]]; then
        args+=("-l" "${selector}")
      fi
      kubectl "${args[@]}" >&2 || true
      return 1
    fi

    sleep 5
  done
}
