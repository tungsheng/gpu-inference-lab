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
'if [[ "$*" == *"output -raw cluster_name"* ]]; then' \
'  printf "%s\n" "gpu-inference"' \
'  exit 0' \
'fi' \
'if [[ "$*" == *"output -raw aws_region"* ]]; then' \
'  printf "%s\n" "us-west-2"' \
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
'  "config current-context")' \
'    printf "%s\n" "arn:aws:eks:us-west-2:123456789012:cluster/dev"' \
'    ;;' \
'  "cluster-info")' \
'    printf "%s\n" "Kubernetes control plane is running"' \
'    ;;' \
'  *"get nodes -o name -l workload=system"*)' \
'    printf "%s\n" "node/cpu-1"' \
'    ;;' \
'  *"get nodes -o name -l workload=gpu"*)' \
'    printf "%s\n" "node/gpu-1"' \
'    ;;' \
'  "get nodes -o name")' \
'    printf "%s\n" "node/cpu-1" "node/gpu-1"' \
'    ;;' \
'  "get deployment metrics-server -n kube-system")' \
'    printf "%s\n" "deployment.apps/metrics-server"' \
'    ;;' \
'  "get service kube-prometheus-stack-prometheus -n monitoring")' \
'    printf "%s\n" "service/kube-prometheus-stack-prometheus"' \
'    ;;' \
'  "get deployment kube-prometheus-stack-grafana -n monitoring")' \
'    printf "%s\n" "deployment.apps/kube-prometheus-stack-grafana"' \
'    ;;' \
'  "get deployment prometheus-adapter -n monitoring")' \
'    printf "%s\n" "deployment.apps/prometheus-adapter"' \
'    ;;' \
'  *"get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath="*)' \
'    printf "%s\n" "True"' \
'    ;;' \
'  "get service pushgateway -n monitoring")' \
'    printf "%s\n" "service/pushgateway"' \
'    ;;' \
'  "get daemonset dcgm-exporter -n monitoring")' \
'    printf "%s\n" "daemonset.apps/dcgm-exporter"' \
'    ;;' \
'  "get podmonitor vllm-metrics -n monitoring")' \
'    printf "%s\n" "podmonitor.monitoring.coreos.com/vllm-metrics"' \
'    ;;' \
'  "get podmonitor karpenter-metrics -n monitoring")' \
'    printf "%s\n" "podmonitor.monitoring.coreos.com/karpenter-metrics"' \
'    ;;' \
'  "get namespace karpenter")' \
'    printf "%s\n" "namespace/karpenter"' \
'    ;;' \
'  "get deployment karpenter -n karpenter")' \
'    printf "%s\n" "deployment.apps/karpenter"' \
'    ;;' \
'  "get crd nodepools.karpenter.sh")' \
'    printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/nodepools.karpenter.sh"' \
'    ;;' \
'  "get crd nodeclaims.karpenter.sh")' \
'    printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/nodeclaims.karpenter.sh"' \
'    ;;' \
'  "get crd ec2nodeclasses.karpenter.k8s.aws")' \
'    printf "%s\n" "customresourcedefinition.apiextensions.k8s.io/ec2nodeclasses.karpenter.k8s.aws"' \
'    ;;' \
'  "get nodepool gpu-serving")' \
'    printf "%s\n" "nodepool.karpenter.sh/gpu-serving"' \
'    ;;' \
'  *"get nodepool gpu-serving -o jsonpath="*)' \
'    printf "%s\n" "True"' \
'    ;;' \
'  "get nodepool gpu-warm-1")' \
'    exit 1' \
'    ;;' \
'  "get ec2nodeclass gpu-serving")' \
'    printf "%s\n" "ec2nodeclass.karpenter.k8s.aws/gpu-serving"' \
'    ;;' \
'  "get daemonset nvidia-device-plugin-daemonset -n kube-system")' \
'    printf "%s\n" "daemonset.apps/nvidia-device-plugin-daemonset"' \
'    ;;' \
'  "get service vllm-openai -n app")' \
'    printf "%s\n" "service/vllm-openai"' \
'    ;;' \
'  "get ingress vllm-openai-ingress -n app")' \
'    printf "%s\n" "ingress.networking.k8s.io/vllm-openai-ingress"' \
'    ;;' \
'  "get nodepools -o name")' \
'    printf "%s\n" "nodepool.karpenter.sh/gpu-serving"' \
'    ;;' \
'  "get nodeclaims -o name")' \
'    printf "%s\n" "nodeclaim.karpenter.sh/gpu-serving-1"' \
'    ;;' \
'  "get deployment -o name -n app")' \
'    printf "%s\n" "deployment.apps/echo" "deployment.apps/vllm-openai"' \
'    ;;' \
'  "get service -o name -n app")' \
'    printf "%s\n" "service/echo" "service/vllm-openai"' \
'    ;;' \
'  "get ingress -o name -n app")' \
'    printf "%s\n" "ingress.networking.k8s.io/echo-ingress" "ingress.networking.k8s.io/vllm-openai-ingress"' \
'    ;;' \
'  "get hpa -o name -n app")' \
'    printf "%s\n" "horizontalpodautoscaler.autoscaling/vllm-openai"' \
'    ;;' \
'  "get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}")' \
'    printf "%s\n" "public-edge.example.com"' \
'    ;;' \
'  "get ingress echo-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}")' \
'    printf "%s\n" "public-edge.example.com"' \
'    ;;' \
'  "get nodes -L workload,node.kubernetes.io/instance-type -o wide")' \
'    printf "%s\n" "NAME STATUS" "gpu-1 Ready"' \
'    ;;' \
'  "get nodepools")' \
'    printf "%s\n" "NAME READY" "gpu-serving True"' \
'    ;;' \
'  "get ec2nodeclasses")' \
'    printf "%s\n" "NAME READY" "gpu-serving True"' \
'    ;;' \
'  "get ingress -n app")' \
'    printf "%s\n" "NAME CLASS" "echo-ingress alb"' \
'    ;;' \
'  "get deployment -n app")' \
'    printf "%s\n" "NAME READY" "echo 1/1"' \
'    ;;' \
'  "get hpa -n app")' \
'    printf "%s\n" "NAME TARGETS" "echo 50%/70%"' \
'    ;;' \
'  "api-resources -o name")' \
'    printf "%s\n" "nodepools.karpenter.sh" "nodeclaims.karpenter.sh" "ec2nodeclasses.karpenter.k8s.aws"' \
'    ;;' \
'  *)' \
'    printf "unexpected kubectl args: %s\n" "$*" >&2' \
'    exit 1' \
'    ;;' \
'esac'

TEST_ENV=(
  "PATH=${TEST_BIN}:/usr/bin:/bin"
  "REPO_ROOT=${FAKE_REPO_ROOT}"
  "TF_DIR=${FAKE_TF_DIR}"
)

run_and_capture env "${TEST_ENV[@]}" /bin/bash "${REPO_ROOT}/scripts/dev" doctor --json
assert_status 0 "${COMMAND_STATUS}" "doctor --json should succeed for a ready environment"
assert_contains "${COMMAND_OUTPUT}" '"ok": true' "doctor JSON should report success"
assert_contains "${COMMAND_OUTPUT}" '"schema_version": 2' "doctor JSON should include a schema version"
assert_contains "${COMMAND_OUTPUT}" '"summary": "environment ready for measurement"' "doctor JSON should include a readable summary"
assert_contains "${COMMAND_OUTPUT}" '"cluster_name": "gpu-inference"' "doctor JSON should include the Terraform cluster name"
assert_contains "${COMMAND_OUTPUT}" '"nvidia_device_plugin_present": true' "doctor JSON should include platform presence details"
assert_contains "${COMMAND_OUTPUT}" '"inference_ingress_present": true' "doctor JSON should include the inference edge presence"
assert_contains "${COMMAND_OUTPUT}" '"prometheus_service_present": true' "doctor JSON should include observability presence"
assert_contains "${COMMAND_OUTPUT}" '"inference_ingress": true' "doctor JSON should preserve the legacy inference ingress alias"
assert_contains "${COMMAND_OUTPUT}" '"warm_gpu_nodepool_present": false' "doctor JSON should report that the warm profile is not active by default"

run_and_capture env "${TEST_ENV[@]}" /bin/bash "${REPO_ROOT}/scripts/dev" status
assert_status 0 "${COMMAND_STATUS}" "status should succeed when the cluster is reachable"
assert_contains "${COMMAND_OUTPUT}" 'measurement: ready' "status should surface measurement readiness in text output"
assert_contains "${COMMAND_OUTPUT}" 'nodes: 2' "status should include node counts in text output"
assert_contains "${COMMAND_OUTPUT}" 'system nodes: 1' "status should include system node counts in text output"
assert_contains "${COMMAND_OUTPUT}" 'gpu nodes: 1' "status should include GPU node counts in text output"
assert_contains "${COMMAND_OUTPUT}" 'public inference URL: http://public-edge.example.com/v1/completions' "status should surface the public inference URL"
assert_contains "${COMMAND_OUTPUT}" 'Prometheus service: present' "status should surface observability presence"
assert_contains "${COMMAND_OUTPUT}" 'warm GPU NodePool: not present' "status should report the warm profile state"

run_and_capture env "${TEST_ENV[@]}" /bin/bash "${REPO_ROOT}/scripts/dev" status --json
assert_status 0 "${COMMAND_STATUS}" "status --json should succeed when the cluster is reachable"
assert_contains "${COMMAND_OUTPUT}" '"ok": true' "status JSON should report cluster reachability"
assert_contains "${COMMAND_OUTPUT}" '"schema_version": 2' "status JSON should include a schema version"
assert_contains "${COMMAND_OUTPUT}" '"ready_for_measurement": true' "status JSON should include measurement readiness"
assert_contains "${COMMAND_OUTPUT}" '"nodes": 2' "status JSON should include node counts"
assert_contains "${COMMAND_OUTPUT}" '"system_nodes": 1' "status JSON should include system node counts"
assert_contains "${COMMAND_OUTPUT}" '"gpu_nodes": 1' "status JSON should include GPU node counts"
assert_contains "${COMMAND_OUTPUT}" '"app_deployments": 2' "status JSON should include app deployment counts"
assert_contains "${COMMAND_OUTPUT}" '"app_services": 2' "status JSON should include both the sample app and inference service"
assert_contains "${COMMAND_OUTPUT}" '"app_ingresses": 2' "status JSON should include both public ingresses"
assert_contains "${COMMAND_OUTPUT}" '"url": "http://public-edge.example.com/v1/completions"' "status JSON should include the public inference URL"
assert_contains "${COMMAND_OUTPUT}" '"prometheus_adapter_deployment_present": true' "status JSON should include the serving metrics adapter"
assert_contains "${COMMAND_OUTPUT}" '"prometheus_adapter": true' "status JSON should preserve the legacy Prometheus adapter alias"
assert_contains "${COMMAND_OUTPUT}" '"warm_gpu_nodepool_present": false' "status JSON should report the warm profile state"

run_and_capture env "${TEST_ENV[@]}" /bin/bash "${REPO_ROOT}/scripts/dev" status --json --verbose
assert_status 1 "${COMMAND_STATUS}" "status should reject combining JSON and verbose modes"
assert_contains "${COMMAND_OUTPUT}" "status accepts either --json or --verbose, not both" "status should explain conflicting output modes"
