#!/usr/bin/env bash

# Shared with the measurement script's cached state collector.
: "${CURRENT_MEASUREMENT_CACHE_KEY-}"

format_duration() {
  local total_seconds=${1:-0}
  local minutes=$((total_seconds / 60))
  local seconds=$((total_seconds % 60))

  printf '%02dm%02ds' "${minutes}" "${seconds}"
}

terminal_columns() {
  local columns=240

  if spinner_enabled && command -v tput >/dev/null 2>&1; then
    columns=$(tput cols 2>/dev/null || printf '240')
  fi

  printf '%s\n' "${columns}"
}

truncate_progress_line() {
  local text=$1
  local max_width

  max_width=$(( $(terminal_columns) - 4 ))

  if (( max_width < 40 )); then
    max_width=40
  fi

  if (( ${#text} <= max_width )); then
    printf '%s\n' "${text}"
    return 0
  fi

  printf '%s...\n' "${text:0:$((max_width - 3))}"
}

spinner_enabled() {
  [[ "${DISABLE_SPINNER}" != "1" && -t 2 ]]
}

progress_target_summary() {
  local wait_mode=${1:-until-ready}
  local target_value=${2:-}

  case "${wait_mode}" in
    at-least)
      printf 'target >= %s\n' "${target_value}"
      ;;
    at-most)
      printf 'target <= %s\n' "${target_value}"
      ;;
    *)
      printf '%s\n' ""
      ;;
  esac
}

build_progress_line() {
  local elapsed_seconds=$1
  local timeout_seconds=$2
  local observed_value=${3:-waiting}
  local wait_mode=${4:-until-ready}
  local target_value=${5:-}
  local progress_line=""
  local time_summary
  local target_summary

  time_summary="$(format_duration "${elapsed_seconds}")/$(format_duration "${timeout_seconds}")"
  target_summary=$(progress_target_summary "${wait_mode}" "${target_value}")

  progress_line="${time_summary} | ${observed_value}"
  if [[ -n "${target_summary}" ]]; then
    progress_line="${progress_line} | ${target_summary}"
  fi

  truncate_progress_line "${progress_line}"
}

write_wait_progress_state() {
  local progress_file=$1
  local observed_value=${2:-waiting}
  local next_file

  if [[ -z "${progress_file}" ]]; then
    return 0
  fi

  next_file="${progress_file}.next"
  printf '%s\n' "${observed_value}" > "${next_file}"
  mv -f "${next_file}" "${progress_file}"
}

# Keep the spinner moving independently from kubectl polling by rendering from
# the latest observed state written by the main wait loop.
progress_spinner_loop() {
  local state_file=$1
  local start_wait=$2
  local timeout_seconds=$3
  local wait_mode=${4:-until-ready}
  local target_value=${5:-}
  local tick_tenths=${SPINNER_INTERVAL_TENTHS}
  local frame_index=0
  local current_state="waiting"
  local next_state=""
  local frame
  local spinner_frame_display
  local elapsed_seconds
  local progress_line

  if (( tick_tenths < 1 )); then
    tick_tenths=1
  fi

  while [[ -f "${state_file}" ]]; do
    next_state=""
    if IFS= read -r next_state < "${state_file}" 2>/dev/null; then
      if [[ -n "${next_state}" ]]; then
        current_state=${next_state}
      fi
    fi

    elapsed_seconds=$(( $(now_epoch) - start_wait ))
    progress_line=$(build_progress_line "${elapsed_seconds}" "${timeout_seconds}" "${current_state}" "${wait_mode}" "${target_value}")

    frame=${SPINNER_FRAMES[$((frame_index % ${#SPINNER_FRAMES[@]}))]}
    frame_index=$((frame_index + 1))
    spinner_frame_display=${frame}

    if color_enabled; then
      spinner_frame_display=$(colorize_text "${LOG_COLOR_INFO}" "${spinner_frame_display}")
    fi

    write_progress '\r'
    write_progress "[$spinner_frame_display] ${progress_line}"
    sleep "$(tenths_to_duration "${tick_tenths}")"
  done
}

start_wait_progress() {
  local start_wait=$1
  local timeout_seconds=$2
  local observed_value=${3:-waiting}
  local wait_mode=${4:-until-ready}
  local target_value=${5:-}

  stop_wait_progress

  if ! spinner_enabled; then
    return 0
  fi

  WAIT_PROGRESS_FILE=$(mktemp "${TMPDIR:-/tmp}/measure-gpu-serving-progress.XXXXXX")
  write_wait_progress_state "${WAIT_PROGRESS_FILE}" "${observed_value}"
  progress_spinner_loop "${WAIT_PROGRESS_FILE}" "${start_wait}" "${timeout_seconds}" "${wait_mode}" "${target_value}" &
  WAIT_SPINNER_PID=$!
}

update_wait_progress_state() {
  local observed_value=${1:-waiting}

  if ! spinner_enabled || [[ -z "${WAIT_PROGRESS_FILE}" ]]; then
    return 0
  fi

  write_wait_progress_state "${WAIT_PROGRESS_FILE}" "${observed_value}"
}

stop_wait_progress() {
  local spinner_pid=${WAIT_SPINNER_PID:-}
  local progress_file=${WAIT_PROGRESS_FILE:-}

  WAIT_SPINNER_PID=""
  WAIT_PROGRESS_FILE=""
  CURRENT_MEASUREMENT_CACHE_KEY=""

  if [[ -n "${progress_file}" ]]; then
    rm -f "${progress_file}" 2>/dev/null || true
    rm -f "${progress_file}.next" 2>/dev/null || true
  fi

  if [[ -n "${spinner_pid}" ]]; then
    wait "${spinner_pid}" 2>/dev/null || true
  fi

  clear_progress_line
}

tenths_to_duration() {
  local tenths=${1:-0}
  local whole_seconds=$((tenths / 10))
  local fractional_tenths=$((tenths % 10))

  printf '%d.%d' "${whole_seconds}" "${fractional_tenths}"
}

render_wait_progress() {
  local description=$1
  local elapsed_seconds=$2
  local timeout_seconds=$3
  local observed_value=${4:-n/a}
  local wait_mode=${5:-until-ready}
  local target_value=${6:-}
  local progress_line=""

  if spinner_enabled; then
    return 0
  fi

  progress_line=$(build_progress_line "${elapsed_seconds}" "${timeout_seconds}" "${observed_value}" "${wait_mode}" "${target_value}")

  if (( elapsed_seconds == 0 || elapsed_seconds - LAST_PROGRESS_LOG_AT >= PROGRESS_LOG_INTERVAL_SECONDS )); then
    log "${description} | ${progress_line}"
    LAST_PROGRESS_LOG_AT=${elapsed_seconds}
  fi
}

write_progress() {
  local text=$1

  printf '%b' "${text}" >&2
}

clear_progress_line() {
  local clear_width

  if ! spinner_enabled; then
    return 0
  fi

  clear_width=$(terminal_columns)

  write_progress '\r'
  write_progress "$(printf '%*s' "${clear_width}" '')"
  write_progress '\r'
}

finish_wait_progress() {
  local description=$1
  local elapsed_seconds=$2
  local observed_value=${3:-n/a}

  stop_wait_progress
  LAST_PROGRESS_LOG_AT=0
  log_success "${description} | $(format_duration "${elapsed_seconds}") | ${observed_value}"
}

fail_wait_progress() {
  local description=$1
  local failure_reason=$2
  local observed_value=${3:-n/a}

  stop_wait_progress
  LAST_PROGRESS_LOG_AT=0
  log_error "${description} | ${failure_reason}"
  log_error "state | ${observed_value}"
}

pause_between_polls() {
  local pause_seconds=$1

  if (( pause_seconds > 0 )); then
    sleep "${pause_seconds}"
  fi
}

now_epoch() {
  date +%s
}

capture_command_output() {
  local output_var_name=$1
  local command_name=${2:-}
  local command_arg=${3:-}
  local output=""

  if [[ -z "${command_name}" ]]; then
    printf -v "${output_var_name}" '%s' ""
    return 0
  fi

  if [[ -n "${command_arg}" ]]; then
    if ! output=$("${command_name}" "${command_arg}"); then
      return 1
    fi
  else
    if ! output=$("${command_name}"); then
      return 1
    fi
  fi

  printf -v "${output_var_name}" '%s' "${output}"
}

run_best_effort_command() {
  local command_name=${1:-}
  local command_arg=${2:-}

  if [[ -z "${command_name}" ]]; then
    return 0
  fi

  if [[ -n "${command_arg}" ]]; then
    "${command_name}" "${command_arg}" || true
    return 0
  fi

  "${command_name}" || true
}

normalize_wait_value() {
  local wait_mode=${1:-value}
  local value=${2:-}

  case "${wait_mode}" in
    at-least|at-most)
      printf '%s\n' "${value:-0}"
      ;;
    *)
      printf '%s\n' "${value}"
      ;;
  esac
}

wait_condition_met() {
  local wait_mode=$1
  local value=${2:-}
  local target_value=${3:-}

  case "${wait_mode}" in
    value)
      [[ -n "${value}" ]]
      ;;
    at-least)
      [[ "${value}" =~ ^[0-9]+$ ]] && (( value >= target_value ))
      ;;
    at-most)
      [[ "${value}" =~ ^[0-9]+$ ]] && (( value <= target_value ))
      ;;
    *)
      return 1
      ;;
  esac
}

remaining_poll_seconds() {
  local loop_started_at=$1
  local pause_seconds=$2
  local time_spent=0

  if (( $(now_epoch) > loop_started_at )); then
    time_spent=$(( $(now_epoch) - loop_started_at ))
  fi

  if (( time_spent >= pause_seconds )); then
    printf '0\n'
  else
    printf '%s\n' "$((pause_seconds - time_spent))"
  fi
}

# Shared wait engine for all measurement checkpoints. Thin wrappers below keep
# the calling sites readable while ensuring logging and timeout behavior stay uniform.
wait_for_condition() {
  local description=$1
  local timeout_seconds=$2
  local wait_mode=${3:-value}
  local target_value=${4:-}
  local value_command=$5
  local snapshot_command=${6:-}
  local failure_command=${7:-}
  local value_arg=${8:-}
  local timeout_command=${9:-}
  local timeout_arg=${10:-}
  local start_wait
  local loop_started_at
  local value
  local normalized_value
  local elapsed_seconds
  local observed_value=""
  local snapshot_value=""
  local failure_reason=""
  local last_snapshot_at=-1
  local last_healthcheck_at=-1
  local pause_seconds

  start_wait=$(now_epoch)
  start_wait_progress "${start_wait}" "${timeout_seconds}" "waiting" "${wait_mode}" "${target_value}"

  while true; do
    loop_started_at=$(now_epoch)
    CURRENT_MEASUREMENT_CACHE_KEY=${loop_started_at}

    if ! capture_command_output value "${value_command}" "${value_arg}"; then
      fail_wait_progress "${description}" "value command failed: ${value_command}" "${observed_value:-waiting}"
      return 1
    fi

    normalized_value=$(normalize_wait_value "${wait_mode}" "${value}")
    elapsed_seconds=$(( loop_started_at - start_wait ))

    if (( elapsed_seconds == 0 || elapsed_seconds - last_healthcheck_at >= API_HEALTHCHECK_INTERVAL_SECONDS )); then
      if ! verify_cluster_connectivity; then
        fail_wait_progress "${description}" "Kubernetes API became unreachable during the measurement run" "${observed_value:-waiting}"
        return 1
      fi
      last_healthcheck_at=${elapsed_seconds}
    fi

    if [[ -z "${observed_value}" || -z "${snapshot_command}" ]] \
      || (( elapsed_seconds == 0 || elapsed_seconds - last_snapshot_at >= STATE_REFRESH_INTERVAL_SECONDS )); then
      if [[ -n "${snapshot_command}" ]]; then
        if ! capture_command_output snapshot_value "${snapshot_command}"; then
          fail_wait_progress "${description}" "state command failed: ${snapshot_command}" "${observed_value:-${normalized_value:-waiting}}"
          return 1
        fi
      else
        snapshot_value=""
      fi

      observed_value=${snapshot_value:-${normalized_value:-waiting}}
      last_snapshot_at=${elapsed_seconds}
    fi

    update_wait_progress_state "${observed_value}"

    if wait_condition_met "${wait_mode}" "${normalized_value}" "${target_value}"; then
      finish_wait_progress "${description}" "${elapsed_seconds}" "${observed_value}"
      printf '%s\n' "${normalized_value}"
      return 0
    fi

    if [[ -n "${failure_command}" ]]; then
      if ! capture_command_output failure_reason "${failure_command}"; then
        fail_wait_progress "${description}" "failure-check command failed: ${failure_command}" "${observed_value}"
        return 1
      fi
    else
      failure_reason=""
    fi

    if [[ -n "${failure_reason}" ]]; then
      fail_wait_progress "${description}" "${failure_reason}" "${observed_value}"
      return 1
    fi

    render_wait_progress "${description}" "${elapsed_seconds}" "${timeout_seconds}" "${observed_value}" "${wait_mode}" "${target_value}"

    if (( elapsed_seconds >= timeout_seconds )); then
      stop_wait_progress
      log_error "${description} timed out after $(format_duration "${elapsed_seconds}")"
      log_error "state | ${observed_value}"

      if [[ -n "${timeout_command}" ]]; then
        run_best_effort_command "${timeout_command}" "${timeout_arg}"
      fi

      return 1
    fi

    pause_seconds=$(remaining_poll_seconds "${loop_started_at}" "${POLL_INTERVAL_SECONDS}")

    if (( pause_seconds > 0 )); then
      pause_between_polls "${pause_seconds}"
    fi
  done
}

wait_for_value() {
  local description=$1
  local timeout_seconds=$2
  local value_command=$3
  local snapshot_command=${4:-}
  local failure_command=${5:-}

  wait_for_condition \
    "${description}" \
    "${timeout_seconds}" \
    "value" \
    "" \
    "${value_command}" \
    "${snapshot_command}" \
    "${failure_command}"
}

wait_for_numeric_at_least() {
  local description=$1
  local timeout_seconds=$2
  local minimum=$3
  local value_command=$4
  local snapshot_command=${5:-}
  local failure_command=${6:-}

  wait_for_condition \
    "${description}" \
    "${timeout_seconds}" \
    "at-least" \
    "${minimum}" \
    "${value_command}" \
    "${snapshot_command}" \
    "${failure_command}"
}

wait_for_numeric_at_most() {
  local description=$1
  local timeout_seconds=$2
  local maximum=$3
  local value_command=$4
  local snapshot_command=${5:-}
  local failure_command=${6:-}

  wait_for_condition \
    "${description}" \
    "${timeout_seconds}" \
    "at-most" \
    "${maximum}" \
    "${value_command}" \
    "${snapshot_command}" \
    "${failure_command}"
}

wait_for_gpu_allocatable() {
  local description=$1
  local timeout_seconds=$2
  local value_command=$3
  local snapshot_command=${4:-}
  local failure_command=${5:-}
  local timeout_command=${6:-}

  wait_for_condition \
    "${description}" \
    "${timeout_seconds}" \
    "at-least" \
    "1" \
    "${value_command}" \
    "${snapshot_command}" \
    "${failure_command}" \
    "" \
    "${timeout_command}"
}
