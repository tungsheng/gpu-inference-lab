#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

stub_terraform "init|destroy"
stub_aws_no_load_balancers
stub_helm_teardown

kubectl_stub_reset
kubectl_bundle_down_happy_path
kubectl_stub_write

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/down should remove the platform stack and destroy terraform state"
assert_contains "${COMMAND_OUTPUT}" "OK 4/8 remove inference and load artifacts" "down should remove runtime artifacts first"
assert_contains "${COMMAND_OUTPUT}" "OK 6/8 remove observability stack" "down should remove observability before destroy"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "down should finish with terraform destroy"

KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")
AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")

assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true" "down should delete the HPA during teardown"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/workloads/validation/gpu-warm-placeholder.yaml --ignore-not-found=true" "down should remove a preserved warm placeholder deployment if one exists"
assert_contains "${KUBECTL_LOG}" "delete daemonset dcgm-exporter -n monitoring --ignore-not-found=true" "down should remove the GPU metrics exporter daemonset"
assert_contains "${KUBECTL_LOG}" "get crd nodepools.karpenter.sh" "down should check the NodePool CRD before deleting NodePools"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/legacy/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true" "down should remove the warm NodePool if it exists"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml --ignore-not-found=true" "down should remove the spot serving NodePool"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml --ignore-not-found=true" "down should remove the on-demand serving NodePool"
assert_contains "${KUBECTL_LOG}" "get crd ec2nodeclasses.karpenter.k8s.aws" "down should check the EC2NodeClass CRD before deleting the node class"
assert_contains "${KUBECTL_LOG}" "get crd nodeclaims.karpenter.sh" "down should check the NodeClaim CRD before waiting for capacity drain"
assert_contains "${KUBECTL_LOG}" "get nodes -l workload=gpu -o name" "down should wait for GPU nodes to drain before uninstalling Karpenter"
assert_contains "${KUBECTL_LOG}" "get crd servicemonitors.monitoring.coreos.com" "down should check the ServiceMonitor CRD before deleting ServiceMonitors"
assert_contains "${KUBECTL_LOG}" "get crd podmonitors.monitoring.coreos.com" "down should check the PodMonitor CRD before deleting PodMonitors"
assert_contains "${KUBECTL_LOG}" "delete ingress vllm-openai-ingress -n app --ignore-not-found=true" "down should delete the inference ingress"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true" "down should delete the inference service"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true" "down should delete the vLLM deployment"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/workloads/validation/gpu-load-test.yaml --ignore-not-found=true" "down should delete the load test job"
assert_not_contains "${KUBECTL_LOG}" "platform/examples/echo" "down should not reference the sample app"
assert_contains "${TERRAFORM_LOG}" "destroy -auto-approve" "down should pass raw terraform arguments through to terraform destroy"
assert_not_contains "${TERRAFORM_LOG}" "destroy --cleanup-orphan-enis -auto-approve" "down should not pass the cleanup flag through to terraform destroy"
assert_not_contains "${AWS_LOG}" "delete-network-interface" "down should not attempt ENI cleanup when terraform destroy succeeds"
