#!/usr/bin/env bash

load_destroy_network_context() {
  local aws_region
  local vpc_id

  if [[ -n "${AWS_REGION:-}" && -n "${VPC_ID:-}" ]]; then
    return 0
  fi

  aws_region=$(try_terraform_output_raw aws_region) || return 1
  vpc_id=$(try_terraform_output_raw vpc_id) || return 1

  AWS_REGION=${aws_region}
  VPC_ID=${vpc_id}
}

load_destroy_cluster_name() {
  local cluster_name

  if [[ -n "${CLUSTER_NAME:-}" ]]; then
    return 0
  fi

  cluster_name=$(try_terraform_output_raw cluster_name) || return 1
  CLUSTER_NAME=${cluster_name}
}

describe_available_vpc_enis() {
  if ! load_destroy_network_context; then
    return 1
  fi

  # shellcheck disable=SC2016
  aws ec2 describe-network-interfaces \
    --region "${AWS_REGION}" \
    --filters \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=status,Values=available" \
    --query 'NetworkInterfaces[].[NetworkInterfaceId,Description,SubnetId,join(`,`,Groups[].GroupId),RequesterId]' \
    --output text
}

describe_non_default_vpc_security_groups() {
  if ! load_destroy_network_context; then
    return 1
  fi

  load_destroy_cluster_name || true

  aws ec2 describe-security-groups \
    --region "${AWS_REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[?GroupName!=\`default\`].[GroupId,GroupName,Description,Tags[?Key==\`kubernetes.io/cluster/${CLUSTER_NAME:-}\`].Value | [0],Tags[?Key==\`karpenter.sh/discovery\`].Value | [0],Tags[?Key==\`Name\`].Value | [0]]" \
    --output text
}

security_group_network_interface_count() {
  local group_id=$1

  if ! load_destroy_network_context; then
    return 1
  fi

  aws ec2 describe-network-interfaces \
    --region "${AWS_REGION}" \
    --filters "Name=group-id,Values=${group_id}" \
    --query 'length(NetworkInterfaces)' \
    --output text
}

destroy_normalized_value() {
  local value=${1:-}

  if [[ "${value}" == "None" ]]; then
    value=""
  fi

  printf '%s\n' "${value}"
}

destroy_display_value() {
  local value

  value=$(destroy_normalized_value "${1:-}")
  if [[ -z "${value}" ]]; then
    printf 'unknown'
  else
    printf '%s' "${value}"
  fi
}

for_each_destroy_eni_row() {
  local rows=$1
  local action=$2
  local eni_id
  local description
  local subnet_id
  local group_ids
  local requester_id

  while IFS=$'\t' read -r eni_id description subnet_id group_ids requester_id; do
    eni_id=$(destroy_normalized_value "${eni_id:-}")
    if [[ -z "${eni_id}" ]]; then
      continue
    fi

    "${action}" \
      "${eni_id}" \
      "$(destroy_normalized_value "${description:-}")" \
      "$(destroy_normalized_value "${subnet_id:-}")" \
      "$(destroy_normalized_value "${group_ids:-}")" \
      "$(destroy_normalized_value "${requester_id:-}")"
  done <<< "${rows}"
}

for_each_destroy_security_group_row() {
  local rows=$1
  local action=$2
  local security_group_id
  local security_group_name
  local description
  local cluster_tag
  local discovery_tag
  local name_tag

  while IFS=$'\t' read -r security_group_id security_group_name description cluster_tag discovery_tag name_tag; do
    security_group_id=$(destroy_normalized_value "${security_group_id:-}")
    if [[ -z "${security_group_id}" ]]; then
      continue
    fi

    "${action}" \
      "${security_group_id}" \
      "$(destroy_normalized_value "${security_group_name:-}")" \
      "$(destroy_normalized_value "${description:-}")" \
      "$(destroy_normalized_value "${cluster_tag:-}")" \
      "$(destroy_normalized_value "${discovery_tag:-}")" \
      "$(destroy_normalized_value "${name_tag:-}")"
  done <<< "${rows}"
}

is_cleanup_eligible_orphan_eni() {
  local description=${1:-}
  local requester_id=${2:-}

  [[ "${description}" == aws-K8S-* || "${requester_id}" == *aws-node* ]]
}

is_cleanup_eligible_orphan_security_group() {
  local group_name=${1:-}
  local description=${2:-}
  local cluster_tag=${3:-}
  local discovery_tag=${4:-}
  local name_tag=${5:-}

  if [[ -z "${CLUSTER_NAME:-}" ]]; then
    return 1
  fi

  if [[ "${cluster_tag}" != "owned" && "${cluster_tag}" != "shared" && "${discovery_tag}" != "${CLUSTER_NAME}" ]]; then
    return 1
  fi

  [[ "${description}" == "EKS node shared security group" || \
    "${name_tag}" == "${CLUSTER_NAME}-node" || \
    "${group_name}" == "${CLUSTER_NAME}-node-"* ]]
}

print_destroy_eni_diagnostic() {
  local eni_id=$1
  local description=$2
  local subnet_id=$3
  local group_ids=$4
  local requester_id=$5
  local cleanup_eligible="no"

  if is_cleanup_eligible_orphan_eni "${description}" "${requester_id}"; then
    cleanup_eligible="yes"
  fi

  printf '    %s subnet=%s groups=%s requester=%s description=%s\n' \
    "${eni_id}" \
    "$(destroy_display_value "${subnet_id}")" \
    "$(destroy_display_value "${group_ids}")" \
    "$(destroy_display_value "${requester_id}")" \
    "$(destroy_display_value "${description}")"
  printf '    cleanup eligible: %s\n' "${cleanup_eligible}"
  if [[ "${cleanup_eligible}" == "yes" ]]; then
    printf '    delete candidate: aws ec2 delete-network-interface --region %s --network-interface-id %s\n' \
      "${AWS_REGION}" \
      "${eni_id}"
  fi
}

print_destroy_security_group_diagnostic() {
  local security_group_id=$1
  local security_group_name=$2
  local description=$3
  local cluster_tag=$4
  local discovery_tag=$5
  local name_tag=$6
  local cleanup_eligible="no"

  if is_cleanup_eligible_orphan_security_group \
    "${security_group_name}" \
    "${description}" \
    "${cluster_tag}" \
    "${discovery_tag}" \
    "${name_tag}"; then
    cleanup_eligible="yes"
  fi

  printf '    %s name=%s description=%s cluster_tag=%s discovery=%s name_tag=%s\n' \
    "${security_group_id}" \
    "$(destroy_display_value "${security_group_name}")" \
    "$(destroy_display_value "${description}")" \
    "$(destroy_display_value "${cluster_tag}")" \
    "$(destroy_display_value "${discovery_tag}")" \
    "$(destroy_display_value "${name_tag}")"
  printf '    cleanup eligible: %s\n' "${cleanup_eligible}"
  if [[ "${cleanup_eligible}" == "yes" ]]; then
    printf '    delete candidate: aws ec2 delete-security-group --region %s --group-id %s\n' \
      "${AWS_REGION}" \
      "${security_group_id}"
  fi
}

print_destroy_dependency_diagnostics() {
  local eni_rows
  local security_group_rows
  local eni_list_status=0
  local security_group_list_status=0

  if [[ "${TERRAFORM_ONLY:-0}" == "1" ]]; then
    return 0
  fi

  if ! load_destroy_network_context; then
    return 0
  fi

  load_destroy_cluster_name || true

  set +e
  eni_rows=$(describe_available_vpc_enis 2>/dev/null)
  eni_list_status=$?
  security_group_rows=$(describe_non_default_vpc_security_groups 2>/dev/null)
  security_group_list_status=$?
  set -e

  printf 'Destroy diagnostics:\n'
  printf '  AWS region: %s\n' "${AWS_REGION}"
  printf '  VPC: %s\n' "${VPC_ID}"

  if [[ "${eni_list_status}" != "0" ]]; then
    printf '  Could not list available ENIs in the VPC.\n'
  elif [[ -z "${eni_rows}" || "${eni_rows}" == "None" ]]; then
    printf '  No available ENIs remain in the VPC.\n'
  else
    printf '  Available ENIs still present in the VPC:\n'
    for_each_destroy_eni_row "${eni_rows}" print_destroy_eni_diagnostic
  fi

  if [[ "${security_group_list_status}" != "0" ]]; then
    printf '  Could not list non-default security groups in the VPC.\n'
  elif [[ -z "${security_group_rows}" || "${security_group_rows}" == "None" ]]; then
    printf '  No non-default security groups remain in the VPC.\n'
  else
    printf '  Non-default security groups still present in the VPC:\n'
    for_each_destroy_security_group_row "${security_group_rows}" print_destroy_security_group_diagnostic
  fi
}

cleanup_orphan_eni_row() {
  local eni_id=$1
  local description=$2
  local subnet_id=$3
  local group_ids=$4
  local requester_id=$5
  local delete_status=0

  if ! is_cleanup_eligible_orphan_eni "${description}" "${requester_id}"; then
    return 0
  fi

  printf '  deleting %s subnet=%s groups=%s requester=%s description=%s\n' \
    "${eni_id}" \
    "$(destroy_display_value "${subnet_id}")" \
    "$(destroy_display_value "${group_ids}")" \
    "$(destroy_display_value "${requester_id}")" \
    "$(destroy_display_value "${description}")"

  set +e
  aws ec2 delete-network-interface \
    --region "${AWS_REGION}" \
    --network-interface-id "${eni_id}" >/dev/null 2>&1
  delete_status=$?
  set -e

  if [[ "${delete_status}" == "0" ]]; then
    ORPHAN_ENI_DELETE_COUNT=$((ORPHAN_ENI_DELETE_COUNT + 1))
    return 0
  fi

  DESTROY_RECOVERY_DELETE_FAILURES=$((DESTROY_RECOVERY_DELETE_FAILURES + 1))
  printf '  failed to delete %s automatically.\n' "${eni_id}"
}

cleanup_orphan_enis() {
  local eni_rows
  local list_status=0

  ORPHAN_ENI_DELETE_COUNT=0
  DESTROY_RECOVERY_DELETE_FAILURES=0

  if ! load_destroy_network_context; then
    printf 'Orphan ENI cleanup:\n'
    printf '  skipped because Terraform outputs could not be loaded.\n'
    return 1
  fi

  set +e
  eni_rows=$(describe_available_vpc_enis 2>/dev/null)
  list_status=$?
  set -e

  printf 'Orphan ENI cleanup:\n'

  if [[ "${list_status}" != "0" ]]; then
    printf '  skipped because available ENIs could not be listed.\n'
    return 1
  fi

  if [[ -z "${eni_rows}" || "${eni_rows}" == "None" ]]; then
    printf '  no available ENIs remain in the VPC.\n'
    return 0
  fi

  for_each_destroy_eni_row "${eni_rows}" cleanup_orphan_eni_row

  if (( ORPHAN_ENI_DELETE_COUNT == 0 )); then
    printf '  no cleanup-eligible orphan aws-K8S ENIs were deleted.\n'
  else
    printf '  deleted %s cleanup-eligible orphan aws-K8S ENI(s).\n' "${ORPHAN_ENI_DELETE_COUNT}"
  fi

  if (( DESTROY_RECOVERY_DELETE_FAILURES > 0 )); then
    return 1
  fi

  return 0
}

cleanup_orphan_security_group_row() {
  local security_group_id=$1
  local security_group_name=$2
  local description=$3
  local cluster_tag=$4
  local discovery_tag=$5
  local name_tag=$6
  local attached_interface_count
  local list_status=0
  local delete_status=0

  if ! is_cleanup_eligible_orphan_security_group \
    "${security_group_name}" \
    "${description}" \
    "${cluster_tag}" \
    "${discovery_tag}" \
    "${name_tag}"; then
    return 0
  fi

  set +e
  attached_interface_count=$(security_group_network_interface_count "${security_group_id}" 2>/dev/null)
  list_status=$?
  set -e

  if [[ "${list_status}" != "0" ]]; then
    DESTROY_RECOVERY_DELETE_FAILURES=$((DESTROY_RECOVERY_DELETE_FAILURES + 1))
    printf '  failed to check network interfaces for %s.\n' "${security_group_id}"
    return 0
  fi

  if [[ "${attached_interface_count}" != "0" ]]; then
    printf '  skipping %s because %s network interface(s) still use it.\n' \
      "${security_group_id}" \
      "${attached_interface_count}"
    return 0
  fi

  printf '  deleting %s name=%s description=%s cluster_tag=%s discovery=%s name_tag=%s\n' \
    "${security_group_id}" \
    "$(destroy_display_value "${security_group_name}")" \
    "$(destroy_display_value "${description}")" \
    "$(destroy_display_value "${cluster_tag}")" \
    "$(destroy_display_value "${discovery_tag}")" \
    "$(destroy_display_value "${name_tag}")"

  set +e
  aws ec2 delete-security-group \
    --region "${AWS_REGION}" \
    --group-id "${security_group_id}" >/dev/null 2>&1
  delete_status=$?
  set -e

  if [[ "${delete_status}" == "0" ]]; then
    ORPHAN_SECURITY_GROUP_DELETE_COUNT=$((ORPHAN_SECURITY_GROUP_DELETE_COUNT + 1))
    return 0
  fi

  DESTROY_RECOVERY_DELETE_FAILURES=$((DESTROY_RECOVERY_DELETE_FAILURES + 1))
  printf '  failed to delete %s automatically.\n' "${security_group_id}"
}

cleanup_orphan_security_groups() {
  local security_group_rows
  local list_status=0

  ORPHAN_SECURITY_GROUP_DELETE_COUNT=0
  DESTROY_RECOVERY_DELETE_FAILURES=0

  if ! load_destroy_network_context; then
    printf 'Orphan security group cleanup:\n'
    printf '  skipped because Terraform outputs could not be loaded.\n'
    return 1
  fi

  load_destroy_cluster_name || true

  set +e
  security_group_rows=$(describe_non_default_vpc_security_groups 2>/dev/null)
  list_status=$?
  set -e

  printf 'Orphan security group cleanup:\n'

  if [[ "${list_status}" != "0" ]]; then
    printf '  skipped because non-default security groups could not be listed.\n'
    return 1
  fi

  if [[ -z "${security_group_rows}" || "${security_group_rows}" == "None" ]]; then
    printf '  no non-default security groups remain in the VPC.\n'
    return 0
  fi

  for_each_destroy_security_group_row "${security_group_rows}" cleanup_orphan_security_group_row

  if (( ORPHAN_SECURITY_GROUP_DELETE_COUNT == 0 )); then
    printf '  no cleanup-eligible orphan EKS node security groups were deleted.\n'
  else
    printf '  deleted %s cleanup-eligible orphan EKS node security group(s).\n' "${ORPHAN_SECURITY_GROUP_DELETE_COUNT}"
  fi

  if (( DESTROY_RECOVERY_DELETE_FAILURES > 0 )); then
    return 1
  fi

  return 0
}
