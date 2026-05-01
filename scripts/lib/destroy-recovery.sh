#!/usr/bin/env bash

load_destroy_network_context() {
  if [[ -n "${AWS_REGION}" && -n "${VPC_ID}" ]]; then
    return 0
  fi

  try_load_cluster_context
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

is_cleanup_eligible_orphan_eni() {
  local description=${1:-}
  local requester_id=${2:-}

  [[ "${description}" == "None" ]] && description=""
  [[ "${requester_id}" == "None" ]] && requester_id=""

  [[ "${description}" == aws-K8S-* || "${requester_id}" == *aws-node* ]]
}

print_destroy_dependency_diagnostics() {
  local eni_rows
  local eni_id
  local description
  local subnet_id
  local group_ids
  local requester_id
  local cleanup_eligible

  if [[ "${TERRAFORM_ONLY:-0}" == "1" ]]; then
    return 0
  fi

  set +e
  eni_rows=$(describe_available_vpc_enis 2>/dev/null)
  set -e

  if ! load_destroy_network_context; then
    return 0
  fi

  printf 'Destroy diagnostics:\n'
  printf '  AWS region: %s\n' "${AWS_REGION}"
  printf '  VPC: %s\n' "${VPC_ID}"

  if [[ -z "${eni_rows}" || "${eni_rows}" == "None" ]]; then
    printf '  No available ENIs remain in the VPC.\n'
    return 0
  fi

  printf '  Available ENIs still present in the VPC:\n'
  while IFS=$'\t' read -r eni_id description subnet_id group_ids requester_id; do
    if [[ -z "${eni_id}" || "${eni_id}" == "None" ]]; then
      continue
    fi

    cleanup_eligible="no"
    if is_cleanup_eligible_orphan_eni "${description:-}" "${requester_id:-}"; then
      cleanup_eligible="yes"
    fi

    printf '    %s subnet=%s groups=%s requester=%s description=%s\n' \
      "${eni_id}" \
      "${subnet_id:-unknown}" \
      "${group_ids:-unknown}" \
      "${requester_id:-unknown}" \
      "${description:-unknown}"
    printf '    cleanup eligible: %s\n' "${cleanup_eligible}"
    if [[ "${cleanup_eligible}" == "yes" ]]; then
      printf '    delete candidate: aws ec2 delete-network-interface --region %s --network-interface-id %s\n' \
        "${AWS_REGION}" \
        "${eni_id}"
    fi
  done <<< "${eni_rows}"
}

cleanup_orphan_enis() {
  local eni_rows
  local eni_id
  local description
  local subnet_id
  local group_ids
  local requester_id
  local list_status=0
  local delete_status=0
  local delete_failures=0

  ORPHAN_ENI_DELETE_COUNT=0

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

  while IFS=$'\t' read -r eni_id description subnet_id group_ids requester_id; do
    if [[ -z "${eni_id}" || "${eni_id}" == "None" ]]; then
      continue
    fi

    if ! is_cleanup_eligible_orphan_eni "${description:-}" "${requester_id:-}"; then
      continue
    fi

    printf '  deleting %s subnet=%s groups=%s requester=%s description=%s\n' \
      "${eni_id}" \
      "${subnet_id:-unknown}" \
      "${group_ids:-unknown}" \
      "${requester_id:-unknown}" \
      "${description:-unknown}"

    set +e
    aws ec2 delete-network-interface \
      --region "${AWS_REGION}" \
      --network-interface-id "${eni_id}" >/dev/null 2>&1
    delete_status=$?
    set -e

    if [[ "${delete_status}" == "0" ]]; then
      ORPHAN_ENI_DELETE_COUNT=$((ORPHAN_ENI_DELETE_COUNT + 1))
      continue
    fi

    delete_failures=$((delete_failures + 1))
    printf '  failed to delete %s automatically.\n' "${eni_id}"
  done <<< "${eni_rows}"

  if (( ORPHAN_ENI_DELETE_COUNT == 0 )); then
    printf '  no cleanup-eligible orphan aws-K8S ENIs were deleted.\n'
  else
    printf '  deleted %s cleanup-eligible orphan aws-K8S ENI(s).\n' "${ORPHAN_ENI_DELETE_COUNT}"
  fi

  if (( delete_failures > 0 )); then
    return 1
  fi

  return 0
}
