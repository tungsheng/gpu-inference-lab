#!/usr/bin/env bash

terraform_wrapper_help_requested() {
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]
}

validate_terraform_wrapper_prereqs() {
  local tf_dir=$1

  require_command terraform
  require_directory "${tf_dir}" "Terraform directory"
}

reject_unsupported_terraform_wrapper_args() {
  local mode=$1
  local tf_dir=$2
  shift 2

  local arg

  for arg in "$@"; do
    case "${mode}:${arg}" in
      apply:-destroy)
        log_error "scripts/apply-dev.sh does not support terraform apply -destroy. Use ./scripts/destroy-dev.sh or terraform -chdir=${tf_dir} destroy directly."
        return 1
        ;;
      apply:-target|apply:-target=*|apply:-refresh-only|apply:-refresh-only=*)
        log_error "scripts/apply-dev.sh only supports full environment apply. Use terraform -chdir=${tf_dir} apply directly for targeted or refresh-only operations."
        return 1
        ;;
      destroy:-target|destroy:-target=*)
        log_error "scripts/destroy-dev.sh only supports full environment teardown. Use terraform -chdir=${tf_dir} destroy directly for targeted destroys."
        return 1
        ;;
    esac
  done

  return 0
}
