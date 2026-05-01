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
"  status|uninstall) exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"if [[ \"\$*\" == 'delete namespace monitoring --ignore-not-found=true' ]]; then" \
"  : > \"${TEST_TMPDIR}/monitoring-deleted\"" \
"  exit 0" \
"fi" \
"if [[ \"\$*\" == 'get namespace monitoring' ]]; then" \
"  if [[ -f \"${TEST_TMPDIR}/monitoring-deleted\" ]]; then" \
"    exit 1" \
"  fi" \
"  exit 0" \
"fi" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
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
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/capacity-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/pushgateway.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete daemonset dcgm-exporter -n monitoring --ignore-not-found=true') exit 0 ;;" \
"  'delete service dcgm-exporter -n monitoring --ignore-not-found=true') exit 0 ;;" \
"  'get crd servicemonitors.monitoring.coreos.com') exit 1 ;;" \
"  'get crd podmonitors.monitoring.coreos.com') exit 1 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get daemonset nvidia-device-plugin-daemonset -n kube-system') exit 1 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"

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
