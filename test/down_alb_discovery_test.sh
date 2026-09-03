#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

stub_terraform "init|destroy"
stub_helm_teardown

write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/aws.log\"" \
"if [[ \"\$1 \$2\" == 'eks update-kubeconfig' ]]; then" \
"  exit 0" \
"fi" \
"if [[ \"\$1 \$2\" == 'elbv2 describe-load-balancers' ]]; then" \
"  if [[ \"\$*\" == *'Type==\`application\`'* ]]; then" \
"    printf '%s\t%s\n' 'arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/public-edge/abc123' 'discovered-edge.example.com'" \
"    exit 0" \
"  fi" \
"  if [[ \"\$*\" == *\"DNSName=='discovered-edge.example.com'\"* ]]; then" \
"    printf '%s\n' '0'" \
"    exit 0" \
"  fi" \
"fi" \
"if [[ \"\$1 \$2\" == 'elbv2 describe-tags' ]]; then" \
"  printf '%s\n' 'public-edge'" \
"  exit 0" \
"fi" \
"printf 'unexpected aws command: %s\n' \"\$*\" >&2" \
"exit 1"


# The ingress reports no hostname, so teardown has to discover the ALB from its
# controller stack tag instead of reading it off the ingress.
kubectl_stub_reset
kubectl_arm "'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}'" "exit 0"
kubectl_bundle_down_happy_path
kubectl_stub_write

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/down should discover and wait for ALB deletion when ingress status is empty"
assert_contains "${COMMAND_OUTPUT}" "OK 4/8 remove inference and load artifacts" "down should still complete runtime cleanup"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "down should still destroy Terraform-managed infrastructure"
assert_not_contains "${COMMAND_OUTPUT}" "No ALB hostname was discovered" "down should not skip ALB deletion wait when the tagged ALB can be discovered"

AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")

assert_contains "${AWS_LOG}" "elbv2 describe-load-balancers --region us-west-2 --query LoadBalancers[?Type==" "down should list application load balancers when ingress status lacks a hostname"
assert_contains "${AWS_LOG}" "elbv2 describe-tags --region us-west-2 --resource-arns arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/public-edge/abc123" "down should inspect ALB controller stack tags"
assert_contains "${AWS_LOG}" "DNSName=='discovered-edge.example.com'" "down should wait for the discovered ALB hostname to disappear"
