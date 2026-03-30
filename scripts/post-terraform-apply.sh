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
. "${SCRIPT_DIR}/lib/platform-install.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/diagnostics.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="post-terraform-apply"
TF_DIR="${TF_DIR:-${TF_DIR_DEFAULT}}"

main() {
  if (($# > 1)); then
    log_error "unexpected extra arguments: $*"
    return 1
  fi

  if (($# == 1)); then
    TF_DIR=$1
  fi

  # shellcheck disable=SC2034
  current_step="reading Terraform outputs"
  require_commands aws helm kubectl terraform
  require_directory "${TF_DIR}" "Terraform directory"
  install_step_error_trap print_apply_diagnostics
  load_required_cluster_context "${TF_DIR}"
  run_step "updating kubeconfig" update_kubeconfig_for_cluster_context
  run_step "verifying cluster connectivity" kubectl cluster-info
  run_post_apply_flow
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
