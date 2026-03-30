#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-paths.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-common.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="apply-dev"
TF_DIR="${TF_DIR_DEFAULT}"

reject_unsupported_apply_args() {
  local arg

  for arg in "$@"; do
    case "${arg}" in
      -destroy)
        log_error "scripts/apply-dev.sh does not support terraform apply -destroy. Use ./scripts/destroy-dev.sh or terraform -chdir=${TF_DIR} destroy directly."
        exit 1
        ;;
      -target|-target=*|-refresh-only|-refresh-only=*)
        log_error "scripts/apply-dev.sh only supports full environment apply. Use terraform -chdir=${TF_DIR} apply directly for targeted or refresh-only operations."
        exit 1
        ;;
    esac
  done
}

require_directory "${TF_DIR}" "Terraform directory"
reject_unsupported_apply_args "$@"

log_section "running terraform apply"
terraform -chdir="${TF_DIR}" apply "$@"
log_section "running cluster post-apply setup"
"${SCRIPT_DIR}/post-terraform-apply.sh" "${TF_DIR}"
log_success "environment apply complete"
