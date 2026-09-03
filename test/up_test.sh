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
"  apply) exit 0 ;;" \
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
"  'iam get-role') exit 1 ;;" \
"  'iam create-service-linked-role') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/helm.log\"" \
"case \"\$1 \$2\" in" \
"  'repo add') exit 0 ;;" \
"  'repo update') exit 0 ;;" \
"  'show crds')" \
"    printf '%s\n' 'apiVersion: apiextensions.k8s.io/v1'" \
"    printf '%s\n' 'kind: CustomResourceDefinition'" \
"    exit 0" \
"    ;;" \
"  'upgrade --install') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

kubectl_stub_reset
kubectl_bundle_up_happy_path
kubectl_stub_write

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/up" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/up should succeed with the expected happy-path tool interactions"
assert_contains "${COMMAND_OUTPUT}" "OK 3/9 terraform apply" "up output should confirm terraform apply"
assert_contains "${COMMAND_OUTPUT}" "OK 5/9 ensure EC2 Spot service-linked role" "up output should confirm the Spot account prerequisite stage"
assert_contains "${COMMAND_OUTPUT}" "OK 7/9 install observability stack" "up output should confirm the observability stage"
assert_contains "${COMMAND_OUTPUT}" "OK 9/9 apply public inference edge" "up output should confirm the inference edge stage"
assert_contains "${COMMAND_OUTPUT}" "Public inference URL: http://public-edge.example.com/v1/completions" "up should print the final public inference URL"
assert_contains "${COMMAND_OUTPUT}" "Grafana: kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000" "up should print the Grafana access hint"

TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")
KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")

assert_contains "${TERRAFORM_LOG}" "apply -auto-approve" "up should pass raw terraform arguments through to terraform apply"
assert_contains "${AWS_LOG}" "iam create-service-linked-role --aws-service-name spot.amazonaws.com" "up should create the Spot service-linked role when it is missing"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml" "up should apply the vLLM PodMonitor"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/observability/dcgm-exporter.yaml" "up should apply the GPU metrics exporter"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml" "up should install the on-demand serving NodePool"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml" "up should install the spot serving NodePool"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/inference/service.yaml" "up should apply the inference service"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml" "up should install the NVIDIA device plugin"
assert_contains "${KUBECTL_LOG}" "apply -f " "up should apply the rendered inference ingress"
assert_contains "${COMMAND_OUTPUT}" "Inference edge scheme=internet-facing inbound-cidrs=203.0.113.10/32" "up should report the resolved edge scheme and source range"
assert_not_contains "${COMMAND_OUTPUT}" "0.0.0.0/0" "up should not open the edge to the internet by default"
assert_contains "${KUBECTL_LOG}" "get nodes -l workload=gpu -o name" "up should verify the zero-GPU baseline before reporting ready"
assert_not_contains "${KUBECTL_LOG}" "platform/examples/echo" "up should not reference the sample app"
