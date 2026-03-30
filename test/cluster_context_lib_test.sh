#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

FAKE_TF_DIR="${TEST_TMPDIR}/infra/env/dev"
mkdir -p "${FAKE_TF_DIR}"

# shellcheck disable=SC2016
write_stub terraform \
'#!/bin/bash' \
'set -euo pipefail' \
'if [[ "$*" == *"output -json"* ]]; then' \
'  printf "%s\n" "{\"cluster_name\":{\"value\":\"gpu-inference\"},\"aws_region\":{\"value\":\"us-west-2\"},\"vpc_id\":{\"value\":\"vpc-123\"},\"aws_load_balancer_controller_role_arn\":{\"value\":\"arn:aws:iam::123456789012:role/alb-controller\"}}"' \
'  exit 0' \
'fi' \
'exit 0'

# shellcheck disable=SC2016
write_stub jq \
'#!/bin/bash' \
'set -euo pipefail' \
'case "$*" in' \
'  *"cluster_name"*) printf "%s\n" "gpu-inference" ;;' \
'  *"aws_region"*) printf "%s\n" "us-west-2" ;;' \
'  *"vpc_id"*) printf "%s\n" "vpc-123" ;;' \
'  *"aws_load_balancer_controller_role_arn"*) printf "%s\n" "arn:aws:iam::123456789012:role/alb-controller" ;;' \
'  *) printf "%s\n" "" ;;' \
'esac'

# shellcheck disable=SC2016
write_stub aws \
'#!/bin/bash' \
'set -euo pipefail' \
'printf "aws:%s\n" "$*"'

# shellcheck disable=SC2016
run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin" REPO_ROOT="${REPO_ROOT}" FAKE_TF_DIR="${FAKE_TF_DIR}" /bin/bash -c '
  set -euo pipefail
  source "${REPO_ROOT}/scripts/dev-environment-common.sh"
  source "${REPO_ROOT}/scripts/lib/terraform.sh"
  source "${REPO_ROOT}/scripts/lib/cluster-context.sh"

  SCRIPT_NAME="cluster-context-test"
  load_required_cluster_context "${FAKE_TF_DIR}"
  printf "required=%s|%s|%s|%s\n" \
    "${CLUSTER_CONTEXT_NAME}" \
    "${CLUSTER_CONTEXT_AWS_REGION}" \
    "${CLUSTER_CONTEXT_VPC_ID}" \
    "${CLUSTER_CONTEXT_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN}"
  update_kubeconfig_for_cluster_context
  load_optional_cluster_context "${FAKE_TF_DIR}"
  printf "optional=%s|%s|%s|%s\n" \
    "${CLUSTER_CONTEXT_NAME}" \
    "${CLUSTER_CONTEXT_AWS_REGION}" \
    "${CLUSTER_CONTEXT_VPC_ID}" \
    "${CLUSTER_CONTEXT_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN}"
'

assert_status 0 "${COMMAND_STATUS}" "cluster context helpers should load Terraform outputs and update kubeconfig"
assert_contains "${COMMAND_OUTPUT}" 'required=gpu-inference|us-west-2|vpc-123|arn:aws:iam::123456789012:role/alb-controller' "required cluster context should load all expected values"
assert_contains "${COMMAND_OUTPUT}" 'aws:eks update-kubeconfig --name gpu-inference --region us-west-2' "cluster context helper should update kubeconfig using the loaded values"
assert_contains "${COMMAND_OUTPUT}" 'optional=gpu-inference|us-west-2||' "optional cluster context should leave apply-only values empty"
