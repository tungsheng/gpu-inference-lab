#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/terraform.log\"" \
"case \"\$2\" in" \
"  init) exit 0 ;;" \
"  destroy) exit 0 ;;" \
"  output)" \
"    case \"\$4\" in" \
"      cluster_name) printf '%s\n' 'gpu-inference' ;;" \
"      aws_region) printf '%s\n' 'us-west-2' ;;" \
"      vpc_id) printf '%s\n' 'vpc-12345' ;;" \
"      aws_load_balancer_controller_role_arn) printf '%s\n' 'arn:aws:iam::123456789012:role/alb-controller' ;;" \
"      *) exit 1 ;;" \
"    esac" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" --terraform-only -auto-approve

assert_status 0 "${COMMAND_STATUS}" "terraform-only down should skip Kubernetes cleanup and destroy Terraform state without aws, helm, or kubectl"
assert_contains "${COMMAND_OUTPUT}" "SKIP 3/8 connect cluster context" "terraform-only mode should skip cluster connection"
assert_contains "${COMMAND_OUTPUT}" "SKIP 4/8 remove inference and load artifacts" "terraform-only mode should skip runtime cleanup"
assert_contains "${COMMAND_OUTPUT}" "SKIP 5/8 delete gpu capacity definitions" "terraform-only mode should skip Kubernetes capacity cleanup"
assert_contains "${COMMAND_OUTPUT}" "SKIP 6/8 remove observability stack" "terraform-only mode should skip observability cleanup"
assert_contains "${COMMAND_OUTPUT}" "SKIP 7/8 uninstall karpenter and nvidia device plugin" "terraform-only mode should skip controller cleanup"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "terraform-only mode should still run terraform destroy"

TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")

assert_contains "${TERRAFORM_LOG}" "destroy -auto-approve" "terraform-only mode should pass Terraform destroy arguments through"
assert_not_contains "${TERRAFORM_LOG}" "destroy --terraform-only -auto-approve" "terraform-only mode should not pass its own flag to Terraform"
assert_file_not_exists "${TEST_TMPDIR}/aws.log" "terraform-only mode should not execute aws commands"
assert_file_not_exists "${TEST_TMPDIR}/helm.log" "terraform-only mode should not execute helm commands"
assert_file_not_exists "${TEST_TMPDIR}/kubectl.log" "terraform-only mode should not execute kubectl commands"
