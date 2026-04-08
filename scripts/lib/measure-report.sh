#!/usr/bin/env bash

MEASURE_REPORT_LIB_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${MEASURE_REPORT_LIB_DIR}/measure-context.sh"
# shellcheck disable=SC1091
. "${MEASURE_REPORT_LIB_DIR}/json.sh"

initialize_event_state() {
  local event_name

  for event_name in "${EVENT_NAMES[@]}"; do
    printf -v "${event_name}" '%s' ""
    printf -v "${event_name}_human" '%s' ""
  done
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

format_duration_seconds() {
  local duration_seconds=${1-}

  if [[ -n "${duration_seconds}" ]]; then
    printf '%ss\n' "${duration_seconds}"
    return 0
  fi

  printf '%s\n' "n/a"
}

format_decimal_value() {
  local value=${1-}
  local suffix=${2:-}

  if [[ -z "${value}" ]]; then
    printf '%s\n' "n/a"
    return 0
  fi

  printf '%s%s\n' "${value}" "${suffix}"
}

format_currency_value() {
  local value=${1-}

  if [[ -z "${value}" ]]; then
    printf '%s\n' "n/a"
    return 0
  fi

  printf '$%s\n' "${value}"
}

seconds_since_start_value() {
  local timestamp=${1-}
  local started_at

  if [[ -z "${timestamp}" ]]; then
    return 0
  fi

  started_at=$(event_timestamp start_time)

  if [[ -z "${started_at}" ]]; then
    return 0
  fi

  printf '%s\n' "$((timestamp - started_at))"
}

seconds_since_start() {
  local timestamp=$1

  format_duration_seconds "$(seconds_since_start_value "${timestamp}")"
}

seconds_between_value() {
  local start_timestamp=${1:-}
  local end_timestamp=${2:-}

  if [[ -z "${start_timestamp}" || -z "${end_timestamp}" ]]; then
    return 0
  fi

  printf '%s\n' "$((end_timestamp - start_timestamp))"
}

seconds_between() {
  local start_timestamp=${1:-}
  local end_timestamp=${2:-}

  format_duration_seconds "$(seconds_between_value "${start_timestamp}" "${end_timestamp}")"
}

event_timestamp() {
  local event_name=$1

  printf '%s\n' "${!event_name:-}"
}

event_timestamp_human() {
  local event_name=$1
  local human_name="${event_name}_human"

  printf '%s\n' "${!human_name:-n/a}"
}

timeline_delta_seconds() {
  local event_name=$1

  if [[ "${event_name}" == "start_time" ]]; then
    printf '%s\n' "0"
    return 0
  fi

  seconds_since_start_value "$(event_timestamp "${event_name}")"
}

timeline_delta_from_start() {
  local event_name=$1

  format_duration_seconds "$(timeline_delta_seconds "${event_name}")"
}

record_event() {
  local event_name=$1
  local event_timestamp_value

  event_timestamp_value=$(now_epoch)
  printf -v "${event_name}" '%s' "${event_timestamp_value}"
  printf -v "${event_name}_human" '%s' "$(timestamp_utc)"
}

render_timeline_rows() {
  local index
  local event_name

  for index in "${!EVENT_NAMES[@]}"; do
    event_name=${EVENT_NAMES[$index]}
    printf '| %s | %s | %s |\n' \
      "${TIMELINE_EVENT_LABELS[$index]}" \
      "$(event_timestamp_human "${event_name}")" \
      "$(timeline_delta_from_start "${event_name}")"
  done
}

render_notes_markdown() {
  cat <<EOF
- Measurements are based on polling the Kubernetes API from this script, not on controller-internal trace timestamps.
- Production summary metrics come from in-cluster vLLM, DCGM, and Karpenter metrics scraped by Prometheus; they do not include ALB or other network overhead.
- The load test uses the checked-in \`platform/tests/gpu-load-test.yaml\` job and targets the in-cluster \`${DEPLOYMENT_NAME}\` service.
- The run intentionally deletes the inference workload at the end to validate full GPU scale-down back to zero nodes.
EOF
}

render_notes_json() {
  cat <<EOF
    $(json_string "Measurements are based on polling the Kubernetes API from this script, not on controller-internal trace timestamps."),
    $(json_string "Production summary metrics come from in-cluster vLLM, DCGM, and Karpenter metrics scraped by Prometheus; they do not include ALB or other network overhead."),
    $(json_string "The load test uses the checked-in platform/tests/gpu-load-test.yaml job and targets the in-cluster ${DEPLOYMENT_NAME} service."),
    $(json_string "The run intentionally deletes the inference workload at the end to validate full GPU scale-down back to zero nodes.")
EOF
}

render_timeline_json_rows() {
  local delimiter=""
  local delta_seconds
  local event_name
  local index
  local observed_at

  for index in "${!EVENT_NAMES[@]}"; do
    event_name=${EVENT_NAMES[$index]}
    observed_at=$(event_timestamp_human "${event_name}")

    if [[ "${observed_at}" == "n/a" ]]; then
      observed_at=""
    fi

    delta_seconds=$(timeline_delta_seconds "${event_name}")

    printf '%s    {\n' "${delimiter}"
    printf '      "name": %s,\n' "$(json_string "${event_name}")"
    printf '      "label": %s,\n' "$(json_string "${TIMELINE_EVENT_LABELS[$index]}")"
    printf '      "observed_at": %s,\n' "$(json_nullable_string "${observed_at}")"
    printf '      "seconds_from_start": %s\n' "$(json_nullable_number "${delta_seconds}")"
    printf '    }'
    delimiter=$',\n'
  done

  printf '\n'
}

render_markdown_report() {
  local public_edge_url="n/a"

  if declare -F inference_edge_url >/dev/null 2>&1; then
    public_edge_url=$(inference_edge_url)
    if [[ -z "${public_edge_url}" ]]; then
      public_edge_url="n/a"
    fi
  fi

  mkdir -p "$(dirname "${REPORT_PATH}")"

  cat > "${REPORT_PATH}" <<EOF
# Dynamic GPU Serving Report

- Generated at: $(timestamp_utc)
- Profile: ${MEASUREMENT_PROFILE}
- Namespace: ${APP_NAMESPACE}
- Deployment: ${DEPLOYMENT_NAME}
- NodeClass: ${NODECLASS_NAME}
- NodePool: ${NODEPOOL_NAME}
- First GPU instance type: ${first_gpu_node_instance_type:-n/a}
- Second GPU instance type: ${second_gpu_node_instance_type:-n/a}
- Public endpoint: ${public_edge_url}
- Poll interval: ${POLL_INTERVAL_SECONDS}s

## Timeline

| Step | Observed at | Delta from start |
| --- | --- | --- |
$(render_timeline_rows)

## Summary

- Cold start to first ready replica: $(seconds_since_start "${first_ready_seen:-}")
- Cold start to first successful external completion: $(seconds_since_start "${first_external_completion_seen:-}")
- Load-triggered scale-out to two ready replicas: $(seconds_between "${load_test_applied:-}" "${second_ready_seen:-}")
- Scale-down after load removal to one GPU node: $(seconds_between "${load_test_deleted:-}" "${scale_in_node_seen:-}")
- Full scale-down to zero GPU nodes after inference deletion: $(seconds_between "${inference_deleted:-}" "${all_gpu_nodes_removed:-}")

## Production Summary

- p95 vLLM request latency during burst: $(format_decimal_value "${PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS:-}" "s")
- p95 time to first token during burst: $(format_decimal_value "${PRODUCTION_P95_TTFT_SECONDS:-}" "s")
- Peak waiting requests during burst: $(format_decimal_value "${PRODUCTION_PEAK_QUEUE_DEPTH:-}")
- Average generation tokens per second during burst: $(format_decimal_value "${PRODUCTION_AVG_GENERATION_TOKENS_PER_SECOND:-}")
- Average GPU utilization during burst: $(format_decimal_value "${PRODUCTION_AVG_GPU_UTILIZATION_PERCENT:-}" "%")
- Max GPU utilization during burst: $(format_decimal_value "${PRODUCTION_MAX_GPU_UTILIZATION_PERCENT:-}" "%")
- Peak active NodeClaims during burst: $(format_decimal_value "${PRODUCTION_PEAK_NODECLAIMS:-}")

## Cost Summary

- Estimated idle cost per hour for profile: $(format_currency_value "${ESTIMATED_IDLE_COST_PER_HOUR:-}")
- Estimated burst cost for this run: $(format_currency_value "${ESTIMATED_BURST_COST:-}")

## Notes

$(render_notes_markdown)
EOF
}

render_json_report() {
  local public_edge_url=""

  if [[ -z "${JSON_REPORT_PATH:-}" ]]; then
    return 0
  fi

  if declare -F inference_edge_url >/dev/null 2>&1; then
    public_edge_url=$(inference_edge_url)
  fi

  mkdir -p "$(dirname "${JSON_REPORT_PATH}")"

  cat > "${JSON_REPORT_PATH}" <<EOF
{
  "schema_version": 2,
  "generated_at": $(json_string "$(timestamp_utc)"),
  "namespace": $(json_string "${APP_NAMESPACE}"),
  "deployment": $(json_string "${DEPLOYMENT_NAME}"),
  "nodeclass": $(json_string "${NODECLASS_NAME}"),
  "nodepool": $(json_string "${NODEPOOL_NAME}"),
  "profile": $(json_string "${MEASUREMENT_PROFILE}"),
  "first_gpu_instance_type": $(json_nullable_string "${first_gpu_node_instance_type:-}"),
  "second_gpu_instance_type": $(json_nullable_string "${second_gpu_node_instance_type:-}"),
  "public_endpoint": $(json_nullable_string "${public_edge_url}"),
  "poll_interval_seconds": $(json_nullable_number "${POLL_INTERVAL_SECONDS}"),
  "timeline": [
$(render_timeline_json_rows)
  ],
  "summary": {
    "cold_start_ready_seconds": $(json_nullable_number "$(seconds_since_start_value "${first_ready_seen:-}")"),
    "cold_start_external_success_seconds": $(json_nullable_number "$(seconds_since_start_value "${first_external_completion_seen:-}")"),
    "scale_out_ready_seconds": $(json_nullable_number "$(seconds_between_value "${load_test_applied:-}" "${second_ready_seen:-}")"),
    "scale_down_to_one_gpu_node_seconds": $(json_nullable_number "$(seconds_between_value "${load_test_deleted:-}" "${scale_in_node_seen:-}")"),
    "scale_down_to_zero_gpu_nodes_seconds": $(json_nullable_number "$(seconds_between_value "${inference_deleted:-}" "${all_gpu_nodes_removed:-}")")
  },
  "production": {
    "p95_vllm_request_latency_seconds": $(json_nullable_number "${PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS:-}"),
    "p95_ttft_seconds": $(json_nullable_number "${PRODUCTION_P95_TTFT_SECONDS:-}"),
    "peak_queue_depth": $(json_nullable_number "${PRODUCTION_PEAK_QUEUE_DEPTH:-}"),
    "average_generation_tokens_per_second": $(json_nullable_number "${PRODUCTION_AVG_GENERATION_TOKENS_PER_SECOND:-}"),
    "average_gpu_utilization_percent": $(json_nullable_number "${PRODUCTION_AVG_GPU_UTILIZATION_PERCENT:-}"),
    "max_gpu_utilization_percent": $(json_nullable_number "${PRODUCTION_MAX_GPU_UTILIZATION_PERCENT:-}"),
    "peak_active_nodeclaims": $(json_nullable_number "${PRODUCTION_PEAK_NODECLAIMS:-}")
  },
  "cost": {
    "estimated_idle_cost_per_hour": $(json_nullable_number "${ESTIMATED_IDLE_COST_PER_HOUR:-}"),
    "estimated_burst_cost": $(json_nullable_number "${ESTIMATED_BURST_COST:-}")
  },
  "notes": [
$(render_notes_json)
  ]
}
EOF
}

render_report() {
  render_markdown_report
  render_json_report
}
