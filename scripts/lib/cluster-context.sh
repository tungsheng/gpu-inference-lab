#!/usr/bin/env bash

# Shared Terraform-derived cluster context for bootstrap and teardown flows.
# shellcheck disable=SC2034
: "${CLUSTER_CONTEXT_NAME-}" "${CLUSTER_CONTEXT_AWS_REGION-}" "${CLUSTER_CONTEXT_VPC_ID-}" "${CLUSTER_CONTEXT_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN-}"

reset_cluster_context() {
  CLUSTER_CONTEXT_NAME=""
  CLUSTER_CONTEXT_AWS_REGION=""
  CLUSTER_CONTEXT_VPC_ID=""
  CLUSTER_CONTEXT_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN=""
}

load_required_cluster_context() {
  local tf_dir=$1

  reset_cluster_context
  CLUSTER_CONTEXT_NAME=$(terraform_output_required "${tf_dir}" cluster_name)
  CLUSTER_CONTEXT_AWS_REGION=$(terraform_output_required "${tf_dir}" aws_region)
  CLUSTER_CONTEXT_VPC_ID=$(terraform_output_required "${tf_dir}" vpc_id)
  CLUSTER_CONTEXT_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN=$(terraform_output_required "${tf_dir}" aws_load_balancer_controller_role_arn)
}

load_optional_cluster_context() {
  local tf_dir=$1

  reset_cluster_context
  CLUSTER_CONTEXT_NAME=$(terraform_output_optional "${tf_dir}" cluster_name)
  CLUSTER_CONTEXT_AWS_REGION=$(terraform_output_optional "${tf_dir}" aws_region)
}

cluster_context_available() {
  [[ -n "${CLUSTER_CONTEXT_NAME}" && -n "${CLUSTER_CONTEXT_AWS_REGION}" ]]
}

update_kubeconfig_for_cluster_context() {
  if ! cluster_context_available; then
    log_error "cluster context is incomplete; cannot update kubeconfig"
    return 1
  fi

  aws eks update-kubeconfig --name "${CLUSTER_CONTEXT_NAME}" --region "${CLUSTER_CONTEXT_AWS_REGION}"
}
