#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-paths.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-common.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/terraform-wrapper.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="apply-dev"
TF_DIR="${TF_DIR:-${TF_DIR_DEFAULT}}"

usage() {
  cat <<EOF
Usage:
  ./scripts/apply-dev.sh [terraform apply args]

Examples:
  ./scripts/apply-dev.sh
  ./scripts/apply-dev.sh -auto-approve
  ./scripts/apply-dev.sh -var-file=dev.tfvars

Notes:
  - This wrapper always runs the full post-apply Kubernetes setup.
  - For targeted or refresh-only operations, use terraform directly.
EOF
}

main() {
  if terraform_wrapper_help_requested "${1:-}"; then
    usage
    return 0
  fi

  validate_terraform_wrapper_prereqs "${TF_DIR}"
  reject_unsupported_terraform_wrapper_args apply "${TF_DIR}" "$@"

  log_section "running terraform apply"
  terraform -chdir="${TF_DIR}" apply "$@"
  log_section "running cluster post-apply setup"
  "${SCRIPT_DIR}/post-terraform-apply.sh" "${TF_DIR}"
  log_success "environment apply complete"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
