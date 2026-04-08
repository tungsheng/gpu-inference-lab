#!/usr/bin/env bash

MEASURE_PRODUCTION_LIB_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${MEASURE_PRODUCTION_LIB_DIR}/measure-context.sh"

measurement_profile_is_warm() {
  [[ "${MEASUREMENT_PROFILE:-zero-idle}" == "warm-1" ]]
}

configure_measurement_profile() {
  local profile_name=${1:-zero-idle}
  local managed_selector="karpenter.sh/nodepool in (${NODEPOOL_NAME},${KARPENTER_WARM_NODEPOOL_NAME})"

  case "${profile_name}" in
    zero-idle)
      # shellcheck disable=SC2034
      MEASUREMENT_PROFILE="zero-idle"
      # shellcheck disable=SC2034
      MEASUREMENT_NODEPOOL_SELECTOR="karpenter.sh/nodepool=${NODEPOOL_NAME}"
      # shellcheck disable=SC2034
      MEASUREMENT_MANAGED_NODEPOOL_SELECTOR="${managed_selector}"
      # shellcheck disable=SC2034
      MEASUREMENT_NODEPOOL_REGEX="^${NODEPOOL_NAME}$"
      ;;
    warm-1)
      # shellcheck disable=SC2034
      MEASUREMENT_PROFILE="warm-1"
      # shellcheck disable=SC2034
      MEASUREMENT_NODEPOOL_SELECTOR="${managed_selector}"
      # shellcheck disable=SC2034
      MEASUREMENT_MANAGED_NODEPOOL_SELECTOR="${managed_selector}"
      # shellcheck disable=SC2034
      MEASUREMENT_NODEPOOL_REGEX="^(${NODEPOOL_NAME}|${KARPENTER_WARM_NODEPOOL_NAME})$"
      ;;
    *)
      log_error "unsupported measurement profile: ${profile_name}"
      log_error "supported profiles: zero-idle, warm-1"
      exit 1
      ;;
  esac
}

remember_gpu_node_instance_type() {
  local slot_name=$1
  local node_name=${2:-}
  local instance_type

  if [[ -z "${node_name}" ]]; then
    return 0
  fi

  instance_type=$(node_instance_type "${node_name}")
  if [[ -z "${instance_type}" ]]; then
    return 0
  fi

  case "${slot_name}" in
    first)
      first_gpu_node_instance_type=${instance_type}
      ;;
    second)
      second_gpu_node_instance_type=${instance_type}
      ;;
  esac
}

render_measurement_warm_nodepool_manifest() {
  local output_path=$1

  sed \
    -e "s/^  name: gpu-warm-1$/  name: ${KARPENTER_WARM_NODEPOOL_NAME}/" \
    -e "s/^        name: gpu-serving$/        name: ${NODECLASS_NAME}/" \
    "${KARPENTER_WARM_NODEPOOL_MANIFEST}" > "${output_path}"
}

run_with_measurement_warm_nodepool_manifest() {
  local callback=$1
  local rendered_manifest
  local status=0

  rendered_manifest=$(mktemp "${TMPDIR:-/tmp}/measure-warm-nodepool.XXXXXX.yaml")
  if render_measurement_warm_nodepool_manifest "${rendered_manifest}"; then
    status=0
  else
    status=$?
    rm -f "${rendered_manifest}" || true
    return "${status}"
  fi

  if "${callback}" "${rendered_manifest}"; then
    status=0
  else
    status=$?
  fi

  rm -f "${rendered_manifest}" || true
  return "${status}"
}

apply_measurement_warm_nodepool() {
  run_with_measurement_warm_nodepool_manifest apply_manifest_quiet
}

delete_measurement_warm_nodepool() {
  run_with_measurement_warm_nodepool_manifest delete_manifest_quiet
}

record_event_once() {
  local event_name=$1

  if [[ -n "$(event_timestamp "${event_name}")" ]]; then
    return 0
  fi

  record_event "${event_name}"
}

prepare_measurement_profile() {
  if ! measurement_profile_is_warm; then
    return 0
  fi

  log "applying the warm GPU NodePool"
  apply_measurement_warm_nodepool

  log "waiting for the warm GPU NodePool to be ready"
  wait_for_status_condition nodepool "${KARPENTER_WARM_NODEPOOL_NAME}" Ready True 300

  log "waiting for the warm GPU NodePool to create a NodeClaim"
  wait_for_numeric_at_least \
    "the warm GPU NodePool to create a NodeClaim" \
    "${WAIT_TIMEOUT_STANDARD_SECONDS}" \
    1 \
    nodeclaim_count \
    serving_state_snapshot >/dev/null

  log "waiting for the warm GPU node to be present in the cluster"
  wait_for_numeric_at_least \
    "the warm GPU node" \
    "${WAIT_TIMEOUT_SCALE_SECONDS}" \
    1 \
    gpu_node_count \
    serving_state_snapshot >/dev/null

  first_gpu_node_name=$(find_gpu_node_name)
  remember_gpu_node_instance_type first "${first_gpu_node_name}"

  log "waiting for GPU allocatable to be available on the warm GPU node"
  wait_for_gpu_allocatable \
    "GPU allocatable on the warm GPU node" \
    "${WAIT_TIMEOUT_STANDARD_SECONDS}" \
    first_gpu_node_allocatable \
    first_gpu_capacity_snapshot \
    "" \
    describe_first_gpu_timeout_context >/dev/null
}

record_profile_baseline_events() {
  if ! measurement_profile_is_warm; then
    return 0
  fi

  if [[ "$(nodeclaim_count)" -ge 1 ]]; then
    record_event_once first_nodeclaim_seen
  fi

  if [[ "$(gpu_node_count)" -ge 1 ]]; then
    if [[ -z "${first_gpu_node_name:-}" ]]; then
      first_gpu_node_name=$(find_gpu_node_name)
    fi
    remember_gpu_node_instance_type first "${first_gpu_node_name}"
    record_event_once first_gpu_node_seen
  fi

  if [[ -n "$(first_gpu_node_allocatable)" ]]; then
    record_event_once first_gpu_allocatable_seen
  fi
}

delete_measurement_profile_capacity() {
  if ! measurement_profile_is_warm; then
    return 0
  fi

  log "deleting the warm GPU NodePool"
  delete_measurement_warm_nodepool
}

measurement_event_seconds_since_start() {
  local event_name=$1
  local event_value=${!event_name:-}

  if [[ -z "${event_value}" || -z "${start_time:-}" ]]; then
    return 0
  fi

  printf '%s\n' "$((event_value - start_time))"
}

measurement_seconds_between_events() {
  local start_event=$1
  local end_event=$2
  local start_value=${!start_event:-}
  local end_value=${!end_event:-}

  if [[ -z "${start_value}" || -z "${end_value}" ]]; then
    return 0
  fi

  printf '%s\n' "$((end_value - start_value))"
}

measurement_lookback_seconds() {
  local finished_at
  local started_at
  local lookback_seconds

  started_at=${start_time:-}
  finished_at=${all_gpu_nodes_removed:-}

  if [[ -z "${started_at}" ]]; then
    printf '900s'
    return 0
  fi

  if [[ -z "${finished_at}" ]]; then
    finished_at=$(now_epoch)
  fi

  lookback_seconds=$((finished_at - started_at + 120))
  if (( lookback_seconds < 300 )); then
    lookback_seconds=300
  fi

  printf '%ss\n' "${lookback_seconds}"
}

start_port_forward() {
  local resource_name=$1
  local resource_namespace=$2
  local remote_port=$3
  local local_port_var_name=$4
  local port_forward_pid_var_name=$5
  local port_forward_log_var_name=$6
  local port_forward_log
  local port_forward_pid
  local local_port=""
  local remaining_attempts=50

  port_forward_log=$(mktemp "${TMPDIR:-/tmp}/measure-port-forward.XXXXXX")
  kubectl port-forward -n "${resource_namespace}" "${resource_name}" ":${remote_port}" >"${port_forward_log}" 2>&1 &
  port_forward_pid=$!

  while (( remaining_attempts > 0 )); do
    if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
      log_warn "port-forward for ${resource_name} exited before it became ready"
      cat "${port_forward_log}" >&2 || true
      rm -f "${port_forward_log}" || true
      return 1
    fi

    local_port=$(sed -n 's/.*127\.0\.0\.1:\([0-9][0-9]*\).*/\1/p' "${port_forward_log}" | head -n 1)
    if [[ -n "${local_port}" ]]; then
      printf -v "${local_port_var_name}" '%s' "${local_port}"
      printf -v "${port_forward_pid_var_name}" '%s' "${port_forward_pid}"
      printf -v "${port_forward_log_var_name}" '%s' "${port_forward_log}"
      return 0
    fi

    remaining_attempts=$((remaining_attempts - 1))
    sleep 0.2
  done

  log_warn "timed out waiting for port-forward readiness on ${resource_name}"
  cat "${port_forward_log}" >&2 || true
  kill "${port_forward_pid}" 2>/dev/null || true
  wait "${port_forward_pid}" 2>/dev/null || true
  rm -f "${port_forward_log}" || true
  return 1
}

stop_port_forward() {
  local port_forward_pid=${1:-}
  local port_forward_log=${2:-}

  if [[ -n "${port_forward_pid}" ]]; then
    kill "${port_forward_pid}" 2>/dev/null || true
    wait "${port_forward_pid}" 2>/dev/null || true
  fi

  if [[ -n "${port_forward_log}" ]]; then
    rm -f "${port_forward_log}" 2>/dev/null || true
  fi
}

stop_measurement_port_forwards() {
  stop_port_forward "${PROMETHEUS_PORT_FORWARD_PID:-}" "${PROMETHEUS_PORT_FORWARD_LOG:-}"
  stop_port_forward "${PUSHGATEWAY_PORT_FORWARD_PID:-}" "${PUSHGATEWAY_PORT_FORWARD_LOG:-}"
  reset_measurement_port_forward_state
}

ensure_prometheus_local_port() {
  if [[ -n "${PROMETHEUS_LOCAL_PORT:-}" ]]; then
    return 0
  fi

  start_port_forward \
    "service/${KUBE_PROMETHEUS_STACK_PROMETHEUS_SERVICE}" \
    "${MONITORING_NAMESPACE}" \
    9090 \
    PROMETHEUS_LOCAL_PORT \
    PROMETHEUS_PORT_FORWARD_PID \
    PROMETHEUS_PORT_FORWARD_LOG
}

ensure_pushgateway_local_port() {
  if [[ -n "${PUSHGATEWAY_LOCAL_PORT:-}" ]]; then
    return 0
  fi

  start_port_forward \
    "service/${PUSHGATEWAY_SERVICE_NAME}" \
    "${MONITORING_NAMESPACE}" \
    9091 \
    PUSHGATEWAY_LOCAL_PORT \
    PUSHGATEWAY_PORT_FORWARD_PID \
    PUSHGATEWAY_PORT_FORWARD_LOG
}

extract_prometheus_scalar() {
  tr -d '\n' | sed -n 's/.*"value":\[[^,]*,"\([^"]*\)"\].*/\1/p'
}

prometheus_query_scalar() {
  local query=$1
  local response
  local scalar_value

  if ! ensure_prometheus_local_port; then
    return 0
  fi

  response=$(curl -fsS --get "http://127.0.0.1:${PROMETHEUS_LOCAL_PORT}/api/v1/query" \
    --data-urlencode "query=${query}" 2>/dev/null || true)
  if [[ -z "${response}" ]]; then
    return 0
  fi

  scalar_value=$(printf '%s' "${response}" | extract_prometheus_scalar)
  if [[ "${scalar_value}" == "NaN" || "${scalar_value}" == "+Inf" || "${scalar_value}" == "-Inf" ]]; then
    return 0
  fi

  printf '%s\n' "${scalar_value}"
}

prometheus_query_scalar_with_fallback() {
  local primary_query=$1
  local fallback_query=${2:-}
  local value

  value=$(prometheus_query_scalar "${primary_query}")
  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  if [[ -n "${fallback_query}" ]]; then
    prometheus_query_scalar "${fallback_query}"
  fi
}

gpu_instance_hourly_cost() {
  case "${1:-}" in
    g4dn.xlarge)
      printf '0.526'
      ;;
    g5.xlarge)
      printf '1.006'
      ;;
    *)
      printf ''
      ;;
  esac
}

multiply_decimal_by_seconds_over_hour() {
  local decimal_value=${1:-}
  local duration_seconds=${2:-}

  if [[ -z "${decimal_value}" || -z "${duration_seconds}" ]]; then
    return 0
  fi

  awk -v rate="${decimal_value}" -v seconds="${duration_seconds}" 'BEGIN { printf "%.6f\n", (rate * seconds) / 3600 }'
}

sum_decimal_values() {
  local first_value=${1:-0}
  local second_value=${2:-0}

  awk -v left="${first_value}" -v right="${second_value}" 'BEGIN { printf "%.6f\n", left + right }'
}

estimate_measurement_costs() {
  local first_node_hourly_cost
  local second_node_hourly_cost
  local first_node_burst_seconds=0
  local second_node_burst_seconds=0
  local first_node_burst_cost
  local second_node_burst_cost

  first_node_hourly_cost=$(gpu_instance_hourly_cost "${first_gpu_node_instance_type:-}")
  second_node_hourly_cost=$(gpu_instance_hourly_cost "${second_gpu_node_instance_type:-}")

  if measurement_profile_is_warm; then
    ESTIMATED_IDLE_COST_PER_HOUR=${first_node_hourly_cost:-}
    first_node_burst_seconds=$(measurement_seconds_between_events start_time all_gpu_nodes_removed)
  else
    ESTIMATED_IDLE_COST_PER_HOUR="0"
    first_node_burst_seconds=$(measurement_seconds_between_events first_gpu_node_seen all_gpu_nodes_removed)
  fi

  second_node_burst_seconds=$(measurement_seconds_between_events second_gpu_node_seen scale_in_node_seen)
  first_node_burst_cost=$(multiply_decimal_by_seconds_over_hour "${first_node_hourly_cost}" "${first_node_burst_seconds}")
  second_node_burst_cost=$(multiply_decimal_by_seconds_over_hour "${second_node_hourly_cost}" "${second_node_burst_seconds}")
  ESTIMATED_BURST_COST=$(sum_decimal_values "${first_node_burst_cost:-0}" "${second_node_burst_cost:-0}")
}

collect_measurement_production_summary() {
  local lookback_window
  local namespace_selector
  local nodepool_regex
  local nodeclaim_query
  local queue_query
  local queue_query_fallback
  local latency_query
  local latency_query_fallback
  local ttft_query
  local ttft_query_fallback
  local throughput_query
  local throughput_query_fallback

  lookback_window=$(measurement_lookback_seconds)
  namespace_selector="{namespace=\"${APP_NAMESPACE}\"}"
  nodepool_regex=${MEASUREMENT_NODEPOOL_REGEX:-^${NODEPOOL_NAME}$}

  queue_query="max_over_time((sum(vllm:num_requests_waiting${namespace_selector}))[${lookback_window}:15s])"
  queue_query_fallback="max_over_time((sum(vllm:num_requests_waiting))[${lookback_window}:15s])"
  latency_query="quantile_over_time(0.95, (histogram_quantile(0.95, sum by (le) (rate(vllm:e2e_request_latency_seconds_bucket${namespace_selector}[1m]))))[${lookback_window}:1m])"
  latency_query_fallback="quantile_over_time(0.95, (histogram_quantile(0.95, sum by (le) (rate(vllm:e2e_request_latency_seconds_bucket[1m]))))[${lookback_window}:1m])"
  ttft_query="quantile_over_time(0.95, (histogram_quantile(0.95, sum by (le) (rate(vllm:time_to_first_token_seconds_bucket${namespace_selector}[1m]))))[${lookback_window}:1m])"
  ttft_query_fallback="quantile_over_time(0.95, (histogram_quantile(0.95, sum by (le) (rate(vllm:time_to_first_token_seconds_bucket[1m]))))[${lookback_window}:1m])"
  throughput_query="avg_over_time((sum(rate(vllm:generation_tokens_total${namespace_selector}[1m])))[${lookback_window}:1m])"
  throughput_query_fallback="avg_over_time((sum(rate(vllm:generation_tokens_total[1m])))[${lookback_window}:1m])"
  nodeclaim_query="max_over_time(((sum(karpenter_nodeclaims_created_total{nodepool=~\"${nodepool_regex}\"}) - sum(karpenter_nodeclaims_terminated_total{nodepool=~\"${nodepool_regex}\"})))[${lookback_window}:1m])"

  # shellcheck disable=SC2034
  PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS=$(prometheus_query_scalar_with_fallback "${latency_query}" "${latency_query_fallback}")
  # shellcheck disable=SC2034
  PRODUCTION_P95_TTFT_SECONDS=$(prometheus_query_scalar_with_fallback "${ttft_query}" "${ttft_query_fallback}")
  # shellcheck disable=SC2034
  PRODUCTION_PEAK_QUEUE_DEPTH=$(prometheus_query_scalar_with_fallback "${queue_query}" "${queue_query_fallback}")
  # shellcheck disable=SC2034
  PRODUCTION_AVG_GENERATION_TOKENS_PER_SECOND=$(prometheus_query_scalar_with_fallback "${throughput_query}" "${throughput_query_fallback}")
  # shellcheck disable=SC2034
  PRODUCTION_AVG_GPU_UTILIZATION_PERCENT=$(prometheus_query_scalar "avg_over_time((avg(DCGM_FI_DEV_GPU_UTIL))[${lookback_window}:1m])")
  # shellcheck disable=SC2034
  PRODUCTION_MAX_GPU_UTILIZATION_PERCENT=$(prometheus_query_scalar "max_over_time((max(DCGM_FI_DEV_GPU_UTIL))[${lookback_window}:1m])")
  # shellcheck disable=SC2034
  PRODUCTION_PEAK_NODECLAIMS=$(prometheus_query_scalar "${nodeclaim_query}")

  estimate_measurement_costs
}

append_pushgateway_metric_line() {
  local output_file=$1
  local metric_name=$2
  local metric_value=${3:-}

  if [[ -z "${metric_value}" ]]; then
    return 0
  fi

  printf '%s %s\n' "${metric_name}" "${metric_value}" >> "${output_file}"
}

push_measurement_summary_metrics() {
  local payload_file
  local push_path

  if ! ensure_pushgateway_local_port; then
    return 0
  fi

  payload_file=$(mktemp "${TMPDIR:-/tmp}/measure-pushgateway.XXXXXX")
  push_path="http://127.0.0.1:${PUSHGATEWAY_LOCAL_PORT}/metrics/job/gpu-serving-measure/profile/${MEASUREMENT_PROFILE}"

  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_first_gpu_node_seconds" "$(measurement_event_seconds_since_start first_gpu_node_seen)"
  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_model_ready_seconds" "$(measurement_event_seconds_since_start first_ready_seen)"
  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_first_external_completion_seconds" "$(measurement_event_seconds_since_start first_external_completion_seen)"
  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_scale_down_to_zero_gpu_nodes_seconds" "$(measurement_seconds_between_events inference_deleted all_gpu_nodes_removed)"
  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_estimated_idle_cost_per_hour" "${ESTIMATED_IDLE_COST_PER_HOUR}"
  append_pushgateway_metric_line "${payload_file}" "gpu_serving_measure_estimated_burst_cost" "${ESTIMATED_BURST_COST}"

  if [[ ! -s "${payload_file}" ]]; then
    rm -f "${payload_file}"
    return 0
  fi

  curl -fsS --data-binary @"${payload_file}" "${push_path}" >/dev/null 2>&1 || \
    log_warn "failed to push measurement summary metrics to Pushgateway"
  rm -f "${payload_file}"
}
