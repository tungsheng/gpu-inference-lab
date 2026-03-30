#!/usr/bin/env bash

# Shared step/error reporting state used with run_step() in lifecycle scripts.
# shellcheck disable=SC2034
: "${current_step-}" "${STEP_ERROR_DIAGNOSTICS_COMMAND-}" "${STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND-}"

step_error_diagnostics_enabled() {
  if [[ -z "${STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND:-}" ]]; then
    return 0
  fi

  "${STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND}"
}

handle_step_error() {
  local exit_code=$1
  local line_number=$2

  trap - ERR
  log_error "failed at line ${line_number} during step: ${current_step}"

  if [[ -n "${STEP_ERROR_DIAGNOSTICS_COMMAND:-}" ]] && step_error_diagnostics_enabled; then
    "${STEP_ERROR_DIAGNOSTICS_COMMAND}"
  fi

  exit "${exit_code}"
}

install_step_error_trap() {
  STEP_ERROR_DIAGNOSTICS_COMMAND=${1:-}
  STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND=${2:-}
  trap 'handle_step_error $? $LINENO' ERR
}

clear_step_error_trap() {
  STEP_ERROR_DIAGNOSTICS_COMMAND=""
  STEP_ERROR_DIAGNOSTICS_GUARD_COMMAND=""
  trap - ERR
}
