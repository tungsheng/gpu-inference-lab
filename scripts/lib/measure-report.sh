#!/usr/bin/env bash

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

seconds_since_start() {
  local timestamp=$1
  local started_at

  if [[ -z "${timestamp}" ]]; then
    printf '%s\n' "n/a"
    return 0
  fi

  started_at=$(event_timestamp start_time)

  if [[ -z "${started_at}" ]]; then
    printf '%s\n' "n/a"
    return 0
  fi

  printf '%ss\n' "$((timestamp - started_at))"
}

seconds_between() {
  local start_timestamp=${1:-}
  local end_timestamp=${2:-}

  if [[ -z "${start_timestamp}" || -z "${end_timestamp}" ]]; then
    printf '%s\n' "n/a"
    return 0
  fi

  printf '%ss\n' "$((end_timestamp - start_timestamp))"
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

timeline_delta_from_start() {
  local event_name=$1

  if [[ "${event_name}" == "start_time" ]]; then
    printf '%s\n' "0s"
    return 0
  fi

  seconds_since_start "$(event_timestamp "${event_name}")"
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

render_report() {
  mkdir -p "$(dirname "${REPORT_PATH}")"

  cat > "${REPORT_PATH}" <<EOF
# Dynamic GPU Serving Report

- Generated at: $(timestamp_utc)
- Namespace: ${APP_NAMESPACE}
- Deployment: ${DEPLOYMENT_NAME}
- NodeClass: ${NODECLASS_NAME}
- NodePool: ${NODEPOOL_NAME}
- Poll interval: ${POLL_INTERVAL_SECONDS}s

## Timeline

| Step | Observed at | Delta from start |
| --- | --- | --- |
$(render_timeline_rows)

## Summary

- Cold start to first Ready replica: $(seconds_since_start "${first_ready_seen:-}")
- Load-triggered scale-out to two Ready replicas: $(seconds_between "${load_test_applied:-}" "${second_ready_seen:-}")
- Scale-down after load removal to one GPU node: $(seconds_between "${load_test_deleted:-}" "${scale_in_node_seen:-}")
- Full scale-down to zero GPU nodes after inference deletion: $(seconds_between "${inference_deleted:-}" "${all_gpu_nodes_removed:-}")

## Notes

- Measurements are based on polling the Kubernetes API from this script, not on controller-internal trace timestamps.
- The load test uses the checked-in \`platform/tests/gpu-load-test.yaml\` job and targets the in-cluster \`${DEPLOYMENT_NAME}\` service.
- The run intentionally deletes the inference workload at the end to validate full GPU scale-down back to zero nodes.
EOF
}
