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

write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml') exit 0 ;;" \
"  'annotate serviceaccount -n kube-system aws-load-balancer-controller eks.amazonaws.com/role-arn=arn:aws:iam::123456789012:role/alb-controller --overwrite') exit 0 ;;" \
"  apply\ -f\ /tmp/*|apply\ -f\ */tmp.*) exit 0 ;;" \
"  'rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=10m') exit 0 ;;" \
"  'get endpoints aws-load-balancer-webhook-service -n kube-system -o jsonpath={.subsets[*].addresses[*].ip}') printf '%s\n' '10.0.0.1' ;;" \
"  'rollout status deployment/kube-prometheus-stack-operator -n monitoring --timeout=10m') exit 0 ;;" \
"  'rollout status deployment/kube-prometheus-stack-grafana -n monitoring --timeout=10m') exit 0 ;;" \
"  'rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/karpenter-podmonitor.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/pushgateway.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/dcgm-exporter.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/dashboards/capacity-dashboard.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml') exit 0 ;;" \
"  'get deployment pushgateway -n monitoring') exit 0 ;;" \
"  'rollout status deployment/pushgateway -n monitoring --timeout=5m') exit 0 ;;" \
"  'get daemonset dcgm-exporter -n monitoring') exit 0 ;;" \
"  'rollout status deployment/prometheus-adapter -n monitoring --timeout=10m') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True' ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml') exit 0 ;;" \
"  'wait --for=condition=Established crd/nodepools.karpenter.sh --timeout=10m') exit 0 ;;" \
"  'wait --for=condition=Established crd/nodeclaims.karpenter.sh --timeout=10m') exit 0 ;;" \
"  'wait --for=condition=Established crd/ec2nodeclasses.karpenter.k8s.aws --timeout=10m') exit 0 ;;" \
"  'rollout status deployment/karpenter -n karpenter --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready ec2nodeclass/gpu-serving --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready nodepool/gpu-serving --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml') exit 0 ;;" \
"  'rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=10m') exit 0 ;;" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/up" -auto-approve

assert_status 0 "${COMMAND_STATUS}" "scripts/up should succeed with the expected happy-path tool interactions"
assert_contains "${COMMAND_OUTPUT}" "OK 3/8 terraform apply" "up output should confirm terraform apply"
assert_contains "${COMMAND_OUTPUT}" "OK 6/8 install observability stack" "up output should confirm the observability stage"
assert_contains "${COMMAND_OUTPUT}" "OK 8/8 apply public inference edge" "up output should confirm the inference edge stage"
assert_contains "${COMMAND_OUTPUT}" "Public inference URL: http://public-edge.example.com/v1/completions" "up should print the final public inference URL"
assert_contains "${COMMAND_OUTPUT}" "Grafana: kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000" "up should print the Grafana access hint"

TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")
KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")

assert_contains "${TERRAFORM_LOG}" "apply -auto-approve" "up should pass raw terraform arguments through to terraform apply"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml" "up should apply the vLLM PodMonitor"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/observability/dcgm-exporter.yaml" "up should apply the GPU metrics exporter"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/inference/ingress.yaml" "up should apply the inference ingress"
assert_not_contains "${KUBECTL_LOG}" "platform/test-app" "up should not reference the sample app"
