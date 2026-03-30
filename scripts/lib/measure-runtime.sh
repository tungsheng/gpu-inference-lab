#!/usr/bin/env bash

# Shared with the measurement wait library during failure cleanup.
: "${LAST_PROGRESS_LOG_AT-}"

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

install_measurement_cleanup_trap() {
  trap cleanup_on_exit EXIT
}
