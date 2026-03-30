#!/usr/bin/env bash

TERRAFORM_OUTPUTS_JSON=""
TERRAFORM_OUTPUTS_JSON_DIR=""
TERRAFORM_OUTPUTS_JSON_LOADED=0

terraform_load_outputs_json() {
  local tf_dir=$1

  if [[ "${TERRAFORM_OUTPUTS_JSON_DIR:-}" == "${tf_dir}" ]]; then
    return 0
  fi

  TERRAFORM_OUTPUTS_JSON=""
  TERRAFORM_OUTPUTS_JSON_DIR="${tf_dir}"
  TERRAFORM_OUTPUTS_JSON_LOADED=0

  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  TERRAFORM_OUTPUTS_JSON=$(terraform -chdir="${tf_dir}" output -json 2>/dev/null || printf '{}')
  TERRAFORM_OUTPUTS_JSON_LOADED=1
}

terraform_output_optional() {
  local tf_dir=$1
  local output_name=$2
  local output_value=""

  terraform_load_outputs_json "${tf_dir}"

  if [[ "${TERRAFORM_OUTPUTS_JSON_LOADED:-0}" == "1" ]]; then
    output_value=$(jq -r --arg output_name "${output_name}" '.[$output_name].value // empty' <<<"${TERRAFORM_OUTPUTS_JSON}" 2>/dev/null || true)
    if [[ "${output_value}" == "null" ]]; then
      output_value=""
    fi
    printf '%s\n' "${output_value}"
    return 0
  fi

  terraform -chdir="${tf_dir}" output -raw "${output_name}" 2>/dev/null || true
}

terraform_output_required() {
  local tf_dir=$1
  local output_name=$2
  local output_value

  output_value=$(terraform_output_optional "${tf_dir}" "${output_name}")

  if [[ -z "${output_value}" ]]; then
    log_error "missing required Terraform output: ${output_name}"
    return 1
  fi

  printf '%s\n' "${output_value}"
}
