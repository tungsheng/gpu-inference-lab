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
. "${SCRIPT_DIR}/lib/terraform.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/cluster-context.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/error-trap.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/platform-destroy.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/diagnostics.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="destroy-dev"
TF_DIR="${TF_DIR:-${TF_DIR_DEFAULT}}"
SKIP_K8S_CLEANUP=${SKIP_K8S_CLEANUP:-0}

current_step="validating prerequisites"

usage() {
  cat <<EOF
Usage:
  ./scripts/destroy-dev.sh [terraform destroy args]

Examples:
  ./scripts/destroy-dev.sh
  ./scripts/destroy-dev.sh -auto-approve
  SKIP_K8S_CLEANUP=1 ./scripts/destroy-dev.sh

Notes:
  - This wrapper tears down Kubernetes resources before destroying Terraform infrastructure.
  - For targeted destroys, use terraform directly.
EOF
}

require_command terraform

reject_unsupported_destroy_args() {
  local arg

  for arg in "$@"; do
    case "${arg}" in
      -target|-target=*)
        log_error "scripts/destroy-dev.sh only supports full environment teardown. Use terraform -chdir=${TF_DIR} destroy directly for targeted destroys."
        exit 1
        ;;
    esac
  done
}

destroy_should_collect_diagnostics() {
  [[ "${SKIP_K8S_CLEANUP}" != "1" ]]
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return 0
  fi

  require_command terraform
  require_directory "${TF_DIR}" "Terraform directory"
  reject_unsupported_destroy_args "$@"
  # shellcheck disable=SC2034
  current_step="reading Terraform outputs"
  install_step_error_trap print_destroy_diagnostics destroy_should_collect_diagnostics
  load_optional_cluster_context "${TF_DIR}"

  if [[ "${SKIP_K8S_CLEANUP}" == "1" ]]; then
    log_warn "skipping Kubernetes cleanup because SKIP_K8S_CLEANUP=1"
  elif cluster_context_available; then
    run_step "validating Kubernetes cleanup prerequisites" require_commands aws helm kubectl
    run_step "updating kubeconfig" update_kubeconfig_for_cluster_context
    run_step "verifying cluster connectivity" verify_cluster_connectivity
    run_destroy_cleanup_flow
  else
    log_error "Terraform outputs for cluster name/region are unavailable; refusing to skip Kubernetes cleanup implicitly. Re-run with SKIP_K8S_CLEANUP=1 if the cluster is already gone and cleanup is intentionally impossible."
    return 1
  fi

  run_step "destroying Terraform-managed infrastructure" terraform -chdir="${TF_DIR}" destroy "$@"
  log_success "environment destroy complete"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
