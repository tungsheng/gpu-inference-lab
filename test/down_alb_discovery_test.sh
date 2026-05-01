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

write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/helm.log\"" \
"case \"\$1\" in" \
"  status) exit 1 ;;" \
"  *) exit 1 ;;" \
"esac"

write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/workloads/validation/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get job gpu-load-test -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/workloads/validation/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment gpu-warm-placeholder -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get hpa vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get service vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  'get crd nodepools.karpenter.sh') exit 1 ;;" \
"  'get crd ec2nodeclasses.karpenter.k8s.aws') exit 1 ;;" \
"  'get crd nodeclaims.karpenter.sh') exit 1 ;;" \
"  'get nodes -l workload=gpu -o name') exit 0 ;;" \
"  'get namespace monitoring') exit 1 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get daemonset nvidia-device-plugin-daemonset -n kube-system') exit 1 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/down should discover and wait for ALB deletion when ingress status is empty"
assert_contains "${COMMAND_OUTPUT}" "OK 4/8 remove inference and load artifacts" "down should still complete runtime cleanup"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "down should still destroy Terraform-managed infrastructure"
assert_not_contains "${COMMAND_OUTPUT}" "No ALB hostname was discovered" "down should not skip ALB deletion wait when the tagged ALB can be discovered"

AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")

assert_contains "${AWS_LOG}" "elbv2 describe-load-balancers --region us-west-2 --query LoadBalancers[?Type==" "down should list application load balancers when ingress status lacks a hostname"
assert_contains "${AWS_LOG}" "elbv2 describe-tags --region us-west-2 --resource-arns arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/public-edge/abc123" "down should inspect ALB controller stack tags"
assert_contains "${AWS_LOG}" "DNSName=='discovered-edge.example.com'" "down should wait for the discovered ALB hostname to disappear"
