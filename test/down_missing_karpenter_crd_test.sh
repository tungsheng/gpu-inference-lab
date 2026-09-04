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

# Same teardown, but every custom resource definition is absent, so the
# NodePool, NodeClass, ServiceMonitor and PodMonitor deletions must be skipped
# rather than attempted. Arms added before a bundle shadow it.
kubectl_stub_reset
kubectl_arm "'get crd nodepools.karpenter.sh'" "exit 1"
kubectl_arm "'get crd ec2nodeclasses.karpenter.k8s.aws'" "exit 1"
kubectl_arm "'get crd nodeclaims.karpenter.sh'" "exit 1"
kubectl_arm "'get crd servicemonitors.monitoring.coreos.com'" "exit 1"
kubectl_arm "'get crd podmonitors.monitoring.coreos.com'" "exit 1"
kubectl_bundle_down_happy_path
kubectl_stub_write

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/down should continue when Karpenter CRDs are already absent"
assert_contains "${COMMAND_OUTPUT}" "Karpenter NodePool CRD is not installed; skipping NodePool deletion." "down should explain skipped NodePool deletion"
assert_contains "${COMMAND_OUTPUT}" "Karpenter EC2NodeClass CRD is not installed; skipping EC2NodeClass deletion." "down should explain skipped EC2NodeClass deletion"
assert_contains "${COMMAND_OUTPUT}" "Karpenter NodeClaim CRD is not installed; skipping NodeClaim drain wait." "down should explain skipped NodeClaim drain wait"
assert_contains "${COMMAND_OUTPUT}" "Prometheus ServiceMonitor CRD is not installed; skipping ServiceMonitor deletion." "down should explain skipped ServiceMonitor deletion"
assert_contains "${COMMAND_OUTPUT}" "Prometheus PodMonitor CRD is not installed; skipping PodMonitor deletion." "down should explain skipped PodMonitor deletion"
assert_contains "${COMMAND_OUTPUT}" "OK 5/8 delete gpu capacity definitions" "missing Karpenter CRDs should not fail the capacity stage"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "down should still destroy Terraform-managed infrastructure"

KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")

assert_contains "${KUBECTL_LOG}" "get crd nodepools.karpenter.sh" "down should check whether the NodePool CRD exists"
assert_contains "${KUBECTL_LOG}" "get crd ec2nodeclasses.karpenter.k8s.aws" "down should check whether the EC2NodeClass CRD exists"
assert_not_contains "${KUBECTL_LOG}" "platform/legacy/karpenter/nodepool-gpu-warm.yaml" "down should not delete NodePool manifests when the CRD is absent"
assert_not_contains "${KUBECTL_LOG}" "platform/karpenter/nodeclass-gpu-serving.yaml" "down should not delete EC2NodeClass manifests when the CRD is absent"
assert_not_contains "${KUBECTL_LOG}" "delete servicemonitor" "down should not delete ServiceMonitor resources when the CRD is absent"
assert_not_contains "${KUBECTL_LOG}" "delete podmonitor" "down should not delete PodMonitor resources when the CRD is absent"
