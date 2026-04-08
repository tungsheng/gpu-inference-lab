#!/usr/bin/env bash

# shellcheck disable=SC2034
# This library owns shared measurement globals that are read across sourced helpers.
SPINNER_FRAMES=("/" "-" "\\" "|")
EVENT_NAMES=(
  start_time
  edge_hostname_seen
  first_pod_seen
  first_nodeclaim_seen
  first_gpu_node_seen
  first_gpu_allocatable_seen
  first_ready_seen
  first_external_completion_seen
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
  "Measurement start"
  "Inference edge hostname available"
  "First serving pod present"
  "First NodeClaim observed"
  "First GPU node observed"
  "GPU allocatable available on first node"
  "First serving pod ready"
  "First successful external completion"
  "Load test applied"
  "HPA desired replicas reached 2"
  "Second NodeClaim observed"
  "Second GPU node observed"
  "Two serving replicas ready"
  "Load test removed"
  "Deployment scaled back to one ready replica"
  "Extra GPU node removed"
  "Inference manifest deleted"
  "All GPU nodes removed"
)

reset_measurement_wait_state() {
  LAST_PROGRESS_LOG_AT=0
  WAIT_PROGRESS_FILE=""
  WAIT_SPINNER_PID=""
}

reset_measurement_port_forward_state() {
  PROMETHEUS_PORT_FORWARD_PID=""
  PROMETHEUS_PORT_FORWARD_LOG=""
  PROMETHEUS_LOCAL_PORT=""
  PUSHGATEWAY_PORT_FORWARD_PID=""
  PUSHGATEWAY_PORT_FORWARD_LOG=""
  PUSHGATEWAY_LOCAL_PORT=""
}

reset_measurement_node_tracking() {
  first_gpu_node_name=""
  first_gpu_node_instance_type=""
  second_gpu_node_name=""
  second_gpu_node_instance_type=""
}

reset_measurement_state_snapshot() {
  MEASUREMENT_STATE_CACHE_KEY=""
  MEASUREMENT_STATE_REFRESHED_AT=""
  STATE_INFERENCE_INGRESS_HOSTNAME=""
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
}

reset_measurement_profile_state() {
  MEASUREMENT_PROFILE="zero-idle"
  MEASUREMENT_NODEPOOL_SELECTOR=""
  MEASUREMENT_MANAGED_NODEPOOL_SELECTOR=""
  MEASUREMENT_NODEPOOL_REGEX=""
}

reset_measurement_production_summary() {
  PRODUCTION_P95_VLLM_REQUEST_LATENCY_SECONDS=""
  PRODUCTION_P95_TTFT_SECONDS=""
  PRODUCTION_PEAK_QUEUE_DEPTH=""
  PRODUCTION_AVG_GENERATION_TOKENS_PER_SECOND=""
  PRODUCTION_AVG_GPU_UTILIZATION_PERCENT=""
  PRODUCTION_MAX_GPU_UTILIZATION_PERCENT=""
  PRODUCTION_PEAK_NODECLAIMS=""
  ESTIMATED_IDLE_COST_PER_HOUR=""
  ESTIMATED_BURST_COST=""
}

initialize_measurement_context() {
  reset_measurement_wait_state
  reset_measurement_port_forward_state
  reset_measurement_node_tracking
  reset_measurement_state_snapshot
  reset_measurement_profile_state
  reset_measurement_production_summary
}

measurement_state_cache_key() {
  printf '%s\n' "${MEASUREMENT_STATE_CACHE_KEY:-}"
}

set_measurement_state_cache_key() {
  MEASUREMENT_STATE_CACHE_KEY=${1:-}
}

clear_measurement_state_cache_key() {
  MEASUREMENT_STATE_CACHE_KEY=""
}
