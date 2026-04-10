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

write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/aws.log\"" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  'elbv2 describe-load-balancers') printf '%s\n' '0' ;;" \
"  *) exit 1 ;;" \
"esac"

write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/helm.log\"" \
"case \"\$1\" in" \
"  uninstall) exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get service vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodepool gpu-serving') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ec2nodeclass gpu-serving') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get daemonset nvidia-device-plugin-daemonset -n kube-system') exit 1 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/down should remove the minimal platform stack and destroy terraform state"
assert_contains "${COMMAND_OUTPUT}" "OK 4/7 remove inference edge" "down should remove the inference edge first"
assert_contains "${COMMAND_OUTPUT}" "OK 7/7 terraform destroy" "down should finish with terraform destroy"

KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")

assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true" "down should delete the ingress during teardown"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml --ignore-not-found=true" "down should remove the GPU NodePool"
assert_not_contains "${KUBECTL_LOG}" "platform/test-app" "down should not reference the sample app"
assert_contains "${TERRAFORM_LOG}" "destroy -auto-approve" "down should pass raw terraform arguments through to terraform destroy"
