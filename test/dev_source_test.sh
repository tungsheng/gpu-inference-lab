#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

FAKE_REPO_ROOT="${TEST_TMPDIR}/repo"
FAKE_TF_DIR="${FAKE_REPO_ROOT}/infra/env/dev"
mkdir -p "${FAKE_TF_DIR}"

# shellcheck disable=SC2016
write_stub terraform \
'#!/bin/bash' \
'set -euo pipefail' \
'if [[ "$*" == *"output -json"* ]]; then' \
'  printf "%s\n" "{\"cluster_name\":{\"value\":\"gpu-inference\"},\"aws_region\":{\"value\":\"us-west-2\"}}"' \
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
'  *) printf "%s\n" "" ;;' \
'esac'

# shellcheck disable=SC2016
write_stub aws \
'#!/bin/bash' \
'set -euo pipefail' \
'exit 0'

# shellcheck disable=SC2016
write_stub helm \
'#!/bin/bash' \
'set -euo pipefail' \
'exit 0'

# shellcheck disable=SC2016
write_stub kubectl \
'#!/bin/bash' \
'set -euo pipefail' \
'case "$*" in' \
'  "config current-context") printf "%s\n" "arn:aws:eks:us-west-2:123456789012:cluster/dev" ;;' \
'  "cluster-info") printf "%s\n" "Kubernetes control plane is running" ;;' \
'  "get deployment metrics-server -n kube-system") printf "%s\n" "deployment.apps/metrics-server" ;;' \
'  "get namespace karpenter") printf "%s\n" "namespace/karpenter" ;;' \
'  "get deployment karpenter -n karpenter") printf "%s\n" "deployment.apps/karpenter" ;;' \
'  "get crd nodepools.karpenter.sh") printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/nodepools.karpenter.sh" ;;' \
'  "get crd nodeclaims.karpenter.sh") printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/nodeclaims.karpenter.sh" ;;' \
'  "get crd ec2nodeclasses.karpenter.k8s.aws") printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/ec2nodeclasses.karpenter.k8s.aws" ;;' \
'  "get nodepool gpu-serving") printf "%s\n" "nodepool.karpenter.sh/gpu-serving" ;;' \
'  "get ec2nodeclass gpu-serving") printf "%s\n" "ec2nodeclass.karpenter.k8s.aws/gpu-serving" ;;' \
'  "get daemonset nvidia-device-plugin-daemonset -n kube-system") printf "%s\n" "daemonset.apps/nvidia-device-plugin-daemonset" ;;' \
'  "get nodes -o name") printf "%s\n" "node/cpu-1" "node/gpu-1" ;;' \
'  "get deployment -o name -n app") printf "%s\n" "deployment.apps/echo" "deployment.apps/vllm-openai" ;;' \
'  "get service -o name -n app") printf "%s\n" "service/echo" ;;' \
'  "get ingress -o name -n app") printf "%s\n" "ingress.networking.k8s.io/echo-ingress" ;;' \
'  "get hpa -o name -n app") printf "%s\n" "horizontalpodautoscaler.autoscaling/echo" ;;' \
'  "api-resources -o name") printf "%s\n" "nodepools.karpenter.sh" "nodeclaims.karpenter.sh" "ec2nodeclasses.karpenter.k8s.aws" ;;' \
'  "get nodepools -o name") printf "%s\n" "nodepool.karpenter.sh/gpu-serving" ;;' \
'  "get nodeclaims -o name") printf "%s\n" "nodeclaim.karpenter.sh/gpu-serving-1" ;;' \
'  *) printf "unexpected kubectl args: %s\n" "$*" >&2; exit 1 ;;' \
'esac'

TEST_ENV=(
  "PATH=${TEST_BIN}:/usr/bin:/bin"
  "REPO_ROOT=${FAKE_REPO_ROOT}"
  "TF_DIR=${FAKE_TF_DIR}"
)

# shellcheck disable=SC2016
run_and_capture env "${TEST_ENV[@]}" /bin/bash -c '
  set -euo pipefail
  source "'"${REPO_ROOT}"'/scripts/dev"
  collect_status_state
  printf "doctor_ready=%s\n" "${DOCTOR_READY}"
  printf "status_ok=%s\n" "${STATUS_OK}"
  printf "status_summary=%s\n" "$(status_summary)"
  render_status_json
'

assert_status 0 "${COMMAND_STATUS}" "sourcing scripts/dev should expose doctor and status helpers without auto-running the CLI"
assert_contains "${COMMAND_OUTPUT}" 'doctor_ready=1' "sourced dev helpers should collect measurement readiness"
assert_contains "${COMMAND_OUTPUT}" 'status_ok=1' "sourced dev helpers should collect cluster counts"
assert_contains "${COMMAND_OUTPUT}" 'status_summary=cluster reachable and ready for measurements' "sourced dev helpers should retain the readiness summary"
assert_contains "${COMMAND_OUTPUT}" '"nodes": 2' "sourced dev helpers should render status JSON with node counts"
