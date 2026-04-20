#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

TEST_PATH_SUFFIX="/usr/bin:/bin:/usr/sbin:/sbin"

write_common_up_stubs() {
  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$2\" in" \
"  init|apply) exit 0 ;;" \
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
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
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
}

write_common_verify_stubs() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"
}

write_common_down_stubs() {
  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$2\" in" \
"  init|destroy) exit 0 ;;" \
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

  write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1\" in" \
"  status|uninstall) exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"
}

write_successful_down_kubectl_stub() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
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
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get job gpu-load-test -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment gpu-warm-placeholder -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get hpa vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get service vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodepool gpu-warm-1') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodepool gpu-serving-spot') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodepool gpu-serving-ondemand') exit 1 ;;" \
"  'delete nodepool/gpu-serving --ignore-not-found=true') exit 0 ;;" \
"  'get nodepool gpu-serving') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ec2nodeclass gpu-serving') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/capacity-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/dcgm-exporter.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/pushgateway.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/karpenter-podmonitor.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get daemonset nvidia-device-plugin-daemonset -n kube-system') exit 1 ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"
}

run_missing_prereq_test() {
  setup_test_tmpdir
  link_system_command dirname
  run_and_capture env PATH="${TEST_BIN}" /bin/bash "${REPO_ROOT}/scripts/up"
  assert_status 1 "${COMMAND_STATUS}" "up should fail fast when required tools are missing"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 1/8 checking prerequisites" "up should fail in the prerequisite stage when tools are missing"
  assert_contains "${COMMAND_OUTPUT}" "Missing required command(s): aws helm kubectl terraform" "up should explain which commands are missing"
  teardown_test_tmpdir
}

run_up_ingress_timeout_test() {
  setup_test_tmpdir
  write_common_up_stubs

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
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
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready nodepool/gpu-serving-ondemand --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready nodepool/gpu-serving-spot --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml') exit 0 ;;" \
"  'rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=10m') exit 0 ;;" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    INGRESS_HOSTNAME_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/up"

  assert_status 1 "${COMMAND_STATUS}" "up should fail when the ingress hostname never appears"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 8/8 apply public inference edge" "up should fail on the inference edge stage when the hostname never appears"
  teardown_test_tmpdir
}

run_verify_gpu_timeout_test() {
  setup_test_tmpdir
  write_common_verify_stubs

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_READY_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when no GPU node ever appears"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 3/6 wait for first gpu node" "verify should fail on the GPU node stage when provisioning never starts"
  teardown_test_tmpdir
}

run_verify_ready_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name') printf '%s\n' 'node/gpu-serving-1' ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when the deployment never becomes ready"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 4/6 wait for ready deployment" "verify should fail on the rollout stage when readiness never completes"
  teardown_test_tmpdir
}

run_verify_response_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name') printf '%s\n' 'node/gpu-serving-1' ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_RESPONSE_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when the public endpoint never returns 200"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/6 wait for first successful response" "verify should fail on the public response stage when curl never succeeds"
  teardown_test_tmpdir
}

run_evaluate_scale_out_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g5.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-ondemand'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'on-demand'; exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/hpa.yaml') exit 0 ;;" \
"  'get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'vllm-openai-0'" \
"    fi" \
"    exit 0" \
"    ;;" \
  "  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*PodScheduled* ) printf '%s\n' '2026-04-10T20:00:10Z'; exit 0 ;;" \
  "  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*containerStatuses*running.startedAt* ) printf '%s\n' '2026-04-10T20:01:30Z'; exit 0 ;;" \
  "  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
  "  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running') printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"0\"}]}'; exit 0 ;;" \
  "  'apply -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml') exit 0 ;;" \
  "  'get job gpu-load-test -n app -o jsonpath={.status.conditions[?(@.type=='\"'\"'Complete'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
  "  'get hpa vllm-openai -n app -o jsonpath={.status.desiredReplicas}') printf '%s\n' '1'; exit 0 ;;" \
  "  *) exit 0 ;;" \
  "esac"

  write_stub curl \
  "#!/usr/bin/env bash" \
  "set -euo pipefail" \
  "cmd=\"\$*\"" \
  "if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
  "  printf '%s' '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"0\"]}]}}'" \
  "  exit 0" \
  "fi" \
  "printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile zero-idle --report "${TEST_TMPDIR}/report.md"

  assert_status 1 "${COMMAND_STATUS}" "evaluate should fail when the HPA never scales out"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 6/10 run load and wait for scale-out" "evaluate should fail in the scale-out stage when desired replicas never increase"
  assert_contains "${COMMAND_OUTPUT}" "Load job completed before HPA scaled out; desired replicas stayed at 1" "evaluate should stop waiting once the load finishes without any scale-out signal"
  teardown_test_tmpdir
}

run_evaluate_metric_pipeline_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g5.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-ondemand'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'on-demand'; exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/hpa.yaml') exit 0 ;;" \
"  'get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'vllm-openai-0'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*PodScheduled* ) printf '%s\n' '2026-04-10T20:00:10Z'; exit 0 ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*containerStatuses*running.startedAt* ) printf '%s\n' '2026-04-10T20:01:30Z'; exit 0 ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  printf '%s' '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"0\"]}]}}'" \
"  exit 0" \
"fi" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    MONITORING_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile zero-idle --report "${TEST_TMPDIR}/report.md"

  assert_status 1 "${COMMAND_STATUS}" "evaluate should fail fast when the HPA metric pipeline never becomes available"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/10 wait for hpa metric pipeline and apply hpa" "evaluate should fail in the metric preflight stage when the custom metric never resolves"
  teardown_test_tmpdir
}

run_evaluate_active_pressure_metric_pipeline_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g5.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-ondemand'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'on-demand'; exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'vllm-openai-0'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*PodScheduled* ) printf '%s\n' '2026-04-10T20:00:10Z'; exit 0 ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*containerStatuses*running.startedAt* ) printf '%s\n' '2026-04-10T20:01:30Z'; exit 0 ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  printf '%s' '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"0\"]}]}}'" \
"  exit 0" \
"fi" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    MONITORING_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile zero-idle --policy active-pressure --report "${TEST_TMPDIR}/report.md"

  assert_status 1 "${COMMAND_STATUS}" "active-pressure evaluate should fail fast when the active metric never becomes available"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/10 active-pressure: wait for hpa metric pipeline and apply hpa" "active-pressure should fail in the metric preflight stage when the custom metric never resolves"
  assert_file_not_exists "${TEST_TMPDIR}/report.md" "active-pressure metric failures should stop before writing a report"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  assert_contains "${KUBECTL_LOG}" "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" "active-pressure failures should preflight the active metric"
  assert_not_contains "${KUBECTL_LOG}" "apply -f /tmp/gpu-lab-active-hpa." "active-pressure metric failures should stop before applying the rendered HPA"

  teardown_test_tmpdir
}

run_evaluate_warm_profile_capacity_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml')" \
"    : > \"${TEST_TMPDIR}/warm-placeholder-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true')" \
"    : > \"${TEST_TMPDIR}/warm-placeholder-deleted\"" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu -o name') exit 0 ;;" \
"  'get deployment gpu-warm-placeholder -n app -o wide')" \
"    if [[ -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'NAME                   READY   UP-TO-DATE   AVAILABLE   AGE'" \
"      printf '%s\n' 'gpu-warm-placeholder   0/1     1            0           5s'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=gpu-warm-placeholder -o wide')" \
"    if [[ -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'NAME                                    READY   STATUS    RESTARTS   AGE   IP      NODE'" \
"      printf '%s\n' 'gpu-warm-placeholder-7c5f5d4df5-abcde   0/1     Pending   0          5s   <none>  <none>'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -o wide') exit 0 ;;" \
"  'get nodes -l workload=gpu -o wide') exit 0 ;;" \
"  'get events -A --sort-by=.lastTimestamp')" \
"    printf '%s\n' 'default  10s  Normal  Ready  nodepool/gpu-warm-1  Status condition transitioned, Type: Ready, Status: Unknown -> True, Reason: Ready'" \
"    exit 0" \
"    ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    EVALUATE_SCALE_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile warm-1 --report "${TEST_TMPDIR}/report.md"

  assert_status 1 "${COMMAND_STATUS}" "evaluate should fail when the warm placeholder never gets a GPU node"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 2/10 prepare evaluation edge and profile" "warm-profile provisioning failures should stop in stage 2"
  assert_contains "${COMMAND_OUTPUT}" "Warm-profile diagnostics:" "warm-profile failures should print inline diagnostics before exiting"
  assert_contains "${COMMAND_OUTPUT}" "preserved for inspection: yes" "warm-profile failures should preserve the placeholder deployment for debugging"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml" "warm profile should apply the placeholder deployment instead of the static NodePool"
  assert_not_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true" "warm-profile failure cleanup should leave the placeholder deployment in place"

  teardown_test_tmpdir
}

run_evaluate_compare_second_policy_failure_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  if [[ \"\$cmd\" == *'kube-prometheus-stack-prometheus'* ]]; then" \
"    printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  else" \
"    printf '%s\n' 'Forwarding from 127.0.0.1:39091 -> 9091'" \
"  fi" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/load-applied\" \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'node/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'nodeclaim/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g5.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-ondemand'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'on-demand'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g4dn.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-spot'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'spot'; exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/hpa.yaml')" \
"    : > \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'vllm-openai-0'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'vllm-openai-1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*PodScheduled* ) printf '%s\n' '2026-04-10T20:00:10Z'; exit 0 ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*containerStatuses*running.startedAt* ) printf '%s\n' '2026-04-10T20:01:30Z'; exit 0 ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running') printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"256\"}]}'; exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active') exit 1 ;;" \
"  'apply -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml')" \
"    : > \"${TEST_TMPDIR}/load-applied\"" \
"    rm -f \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'get job gpu-load-test -n app -o jsonpath={.status.conditions[?(@.type=='\"'\"'Complete'\"'\"')].status}')" \
"    if [[ -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"      printf '%s\n' 'True'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get hpa vllm-openai -n app -o jsonpath={.status.desiredReplicas}')" \
"    if [[ -f \"${TEST_TMPDIR}/hpa-applied\" ]]; then" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' '2'" \
"      else" \
"        printf '%s\n' '1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get deployment vllm-openai -n app -o jsonpath={.status.readyReplicas}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' '2'" \
"      else" \
"        printf '%s\n' '1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'wait --for=condition=complete job/gpu-load-test -n app --timeout=1200s')" \
"    rm -f \"${TEST_TMPDIR}/load-applied\"" \
"    : > \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'get hpa vllm-openai -n app') exit 1 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  printf '%s' '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"1.25\"]}]}}'" \
"  exit 0" \
"fi" \
"if [[ \"\$cmd\" == *'--data-binary @'* ]]; then" \
"  exit 0" \
"fi" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    TMPDIR=/tmp \
    POLL_INTERVAL_SECONDS=0 \
    MONITORING_TIMEOUT_SECONDS=1 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile zero-idle --policy compare --report "${TEST_TMPDIR}/compare.md" --json-report "${TEST_TMPDIR}/compare.json"

  assert_status 1 "${COMMAND_STATUS}" "compare mode should stop when the second policy cannot resolve its metric"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/10 active-pressure: wait for hpa metric pipeline and apply hpa" "compare mode should surface the active-pressure metric preflight failure"
  assert_not_contains "${COMMAND_OUTPUT}" "Compared:" "compare mode should not print a compare summary when the second policy fails"
  assert_file_exists "${TEST_TMPDIR}/compare-running.md" "compare mode should preserve the completed running-policy Markdown report"
  assert_file_exists "${TEST_TMPDIR}/compare-running.json" "compare mode should preserve the completed running-policy JSON report"
  assert_file_not_exists "${TEST_TMPDIR}/compare-active-pressure.md" "compare mode should stop before writing the failing active-pressure Markdown report"
  assert_file_not_exists "${TEST_TMPDIR}/compare-active-pressure.json" "compare mode should stop before writing the failing active-pressure JSON report"
  assert_file_not_exists "${TEST_TMPDIR}/compare-compare.md" "compare mode should not write the compare Markdown report when policy two fails"
  assert_file_not_exists "${TEST_TMPDIR}/compare-compare.json" "compare mode should not write the compare JSON report when policy two fails"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  assert_occurs_before "${KUBECTL_LOG}" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" \
    "compare mode should finish the running-policy preflight before the active-pressure preflight fails"
  assert_not_contains "${KUBECTL_LOG}" "apply -f /tmp/gpu-lab-active-hpa." "compare mode should stop before applying the active-pressure HPA when the metric preflight fails"

  teardown_test_tmpdir
}

run_evaluate_sweep_second_target_failure_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$1\" == 'port-forward' ]]; then" \
"  if [[ \"\$cmd\" == *'kube-prometheus-stack-prometheus'* ]]; then" \
"    printf '%s\n' 'Forwarding from 127.0.0.1:39090 -> 9090'" \
"  else" \
"    printf '%s\n' 'Forwarding from 127.0.0.1:39091 -> 9091'" \
"  fi" \
"  sleep 30" \
"  exit 0" \
"fi" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/load-applied\" \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'node/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'nodeclaim/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g5.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-ondemand'; exit 0 ;;" \
"  'get node gpu-serving-1 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'on-demand'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g4dn.xlarge'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.karpenter\.sh/nodepool}') printf '%s\n' 'gpu-serving-spot'; exit 0 ;;" \
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.karpenter\.sh/capacity-type}') printf '%s\n' 'spot'; exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  apply\ -f\ /tmp/gpu-lab-active-hpa.*)" \
"    : > \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=vllm-openai --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      printf '%s\n' 'vllm-openai-0'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'vllm-openai-1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*PodScheduled* ) printf '%s\n' '2026-04-10T20:00:10Z'; exit 0 ;;" \
"  get\ pod\ vllm-openai-0\ -n\ app\ -o\ jsonpath=*containerStatuses*running.startedAt* ) printf '%s\n' '2026-04-10T20:01:30Z'; exit 0 ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active')" \
"    metric_check_count=0" \
"    if [[ -f \"${TEST_TMPDIR}/active-metric-check-count\" ]]; then" \
"      metric_check_count=\$(cat \"${TEST_TMPDIR}/active-metric-check-count\")" \
"    fi" \
"    metric_check_count=\$((metric_check_count + 1))" \
"    printf '%s\n' \"\${metric_check_count}\" > \"${TEST_TMPDIR}/active-metric-check-count\"" \
"    if [[ \"\${metric_check_count}\" == '1' ]]; then" \
"      printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"320\"}]}'" \
"      exit 0" \
"    fi" \
"    exit 1" \
"    ;;" \
"  'apply -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml')" \
"    : > \"${TEST_TMPDIR}/load-applied\"" \
"    rm -f \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'get job gpu-load-test -n app -o jsonpath={.status.conditions[?(@.type=='\"'\"'Complete'\"'\"')].status}')" \
"    if [[ -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"      printf '%s\n' 'True'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get hpa vllm-openai -n app -o jsonpath={.status.desiredReplicas}')" \
"    if [[ -f \"${TEST_TMPDIR}/hpa-applied\" ]]; then" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' '2'" \
"      else" \
"        printf '%s\n' '1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get deployment vllm-openai -n app -o jsonpath={.status.readyReplicas}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' '2'" \
"      else" \
"        printf '%s\n' '1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'wait --for=condition=complete job/gpu-load-test -n app --timeout=1200s')" \
"    rm -f \"${TEST_TMPDIR}/load-applied\"" \
"    : > \"${TEST_TMPDIR}/load-finished\"" \
"    exit 0" \
"    ;;" \
"  'get hpa vllm-openai -n app') exit 1 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  printf '%s' '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"1.25\"]}]}}'" \
"  exit 0" \
"fi" \
"if [[ \"\$cmd\" == *'--data-binary @'* ]]; then" \
"  exit 0" \
"fi" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    TMPDIR=/tmp \
    POLL_INTERVAL_SECONDS=0 \
    MONITORING_TIMEOUT_SECONDS=1 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile zero-idle --policy sweep --active-targets 2,4,8 --report "${TEST_TMPDIR}/sweep.md" --json-report "${TEST_TMPDIR}/sweep.json"

  assert_status 1 "${COMMAND_STATUS}" "sweep mode should stop when a later target cannot resolve its metric"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/10 active-pressure@4: wait for hpa metric pipeline and apply hpa" "sweep mode should surface the later target metric preflight failure"
  assert_not_contains "${COMMAND_OUTPUT}" "Swept:" "sweep mode should not print a sweep summary when a later target fails"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-2.md" "sweep mode should preserve the completed target-2 Markdown report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-2.json" "sweep mode should preserve the completed target-2 JSON report"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-target-4.md" "sweep mode should stop before writing the failing target-4 Markdown report"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-target-4.json" "sweep mode should stop before writing the failing target-4 JSON report"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-target-8.md" "sweep mode should stop before reaching the target-8 Markdown report"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-target-8.json" "sweep mode should stop before reaching the target-8 JSON report"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-sweep.md" "sweep mode should not write the sweep Markdown report when a later target fails"
  assert_file_not_exists "${TEST_TMPDIR}/sweep-active-pressure-sweep.json" "sweep mode should not write the sweep JSON report when a later target fails"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")
  ACTIVE_METRIC_CHECK_COUNT=$(printf '%s\n' "${KUBECTL_LOG}" | awk -v needle="get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" 'index($0, needle) { count++ } END { print count + 0 }')
  ACTIVE_HPA_APPLY_COUNT=$(printf '%s\n' "${KUBECTL_LOG}" | awk -v needle="apply -f /tmp/gpu-lab-active-hpa." 'index($0, needle) { count++ } END { print count + 0 }')

  if (( ACTIVE_METRIC_CHECK_COUNT < 2 )); then
    fail "sweep mode should preflight the active metric for the successful and failing targets"
  fi
  assert_eq "1" "${ACTIVE_HPA_APPLY_COUNT}" "sweep mode should only apply the rendered active-pressure HPA for the successful first target"
  assert_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/zero-idle/resilience/healthy/policy/active-pressure/target/2" "sweep mode should keep the first successful target push"
  assert_not_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/zero-idle/resilience/healthy/policy/active-pressure/target/4" "sweep mode should stop before pushing the failing target summary"

  teardown_test_tmpdir
}

run_evaluate_compare_warm_profile_capacity_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"cmd=\"\$*\"" \
"case \"\$cmd\" in" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True'; exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com'; exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml')" \
"    : > \"${TEST_TMPDIR}/warm-placeholder-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true')" \
"    : > \"${TEST_TMPDIR}/warm-placeholder-deleted\"" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu -o name') exit 0 ;;" \
"  'get deployment gpu-warm-placeholder -n app -o wide')" \
"    if [[ -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'NAME                   READY   UP-TO-DATE   AVAILABLE   AGE'" \
"      printf '%s\n' 'gpu-warm-placeholder   0/1     1            0           5s'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get pods -n app -l app=gpu-warm-placeholder -o wide')" \
"    if [[ -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'NAME                                    READY   STATUS    RESTARTS   AGE   IP      NODE'" \
"      printf '%s\n' 'gpu-warm-placeholder-7c5f5d4df5-abcde   0/1     Pending   0          5s   <none>  <none>'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -o wide') exit 0 ;;" \
"  'get nodes -l workload=gpu -o wide') exit 0 ;;" \
"  'get events -A --sort-by=.lastTimestamp')" \
"    printf '%s\n' 'default  10s  Normal  Ready  nodepool/gpu-warm-1  Status condition transitioned, Type: Ready, Status: Unknown -> True, Reason: Ready'" \
"    exit 0" \
"    ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '200'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    EVALUATE_SCALE_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" --profile warm-1 --policy compare --report "${TEST_TMPDIR}/compare.md"

  assert_status 1 "${COMMAND_STATUS}" "compare mode should fail when the warm placeholder never gets a GPU node"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 2/10 running: prepare evaluation edge and profile" "compare warm-profile failures should preserve the running-policy stage label"
  assert_contains "${COMMAND_OUTPUT}" "Warm-profile diagnostics:" "compare warm-profile failures should still print inline diagnostics"
  assert_contains "${COMMAND_OUTPUT}" "preserved for inspection: yes" "compare warm-profile failures should preserve the placeholder deployment for debugging"

  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml" "compare warm-profile failures should still apply the placeholder deployment"
  assert_not_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true" "compare warm-profile failures should leave the placeholder deployment in place"

  teardown_test_tmpdir
}

run_down_alb_timeout_test() {
  setup_test_tmpdir
  write_common_down_stubs

  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  'elbv2 describe-load-balancers') printf '%s\n' '1' ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get job gpu-load-test -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get hpa vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get service vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_CLEANUP_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/down"

  assert_status 1 "${COMMAND_STATUS}" "down should fail when the ALB never disappears after ingress deletion"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 4/8 remove inference and load artifacts" "down should fail on runtime teardown when ALB deletion stalls"
  teardown_test_tmpdir
}

run_down_cluster_unreachable_test() {
  setup_test_tmpdir
  write_common_down_stubs

  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'cluster-info') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

  assert_status 1 "${COMMAND_STATUS}" "down should stop before terraform destroy when the cluster cannot be reached"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 3/8 connect cluster context" "down should fail in the cluster connection stage when the cluster is unreachable"
  assert_contains "${COMMAND_OUTPUT}" "terraform -chdir=${REPO_ROOT}/infra/env/dev destroy -auto-approve" "down should print the exact manual fallback destroy command"
  teardown_test_tmpdir
}

run_down_destroy_dependency_diagnostics_test() {
  setup_test_tmpdir
  write_common_down_stubs
  write_successful_down_kubectl_stub

  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$2\" in" \
"  init) exit 0 ;;" \
"  destroy) exit 1 ;;" \
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
"  'ec2 describe-network-interfaces')" \
"    printf '%s\t%s\t%s\t%s\t%s\n' 'eni-03c6a627c2ce46d98' 'aws-K8S-i-0f9e65492af4c27fb' 'subnet-03085888abd0f7244' 'sg-0f9c872d13021f5ef' 'AROATBRKPOLXETKDLLAAM:eks-gpu-infere-aws-node-c-c810c7b3-5f72-4719-b476-c634ee062d4e'" \
"    exit 0" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

  assert_status 1 "${COMMAND_STATUS}" "down should fail when terraform destroy hits a dependency violation"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 8/8 terraform destroy" "down should report the terraform destroy stage failure"
  assert_contains "${COMMAND_OUTPUT}" "Destroy diagnostics:" "down should print destroy diagnostics when terraform destroy fails"
  assert_contains "${COMMAND_OUTPUT}" "VPC: vpc-12345" "down diagnostics should include the VPC id"
  assert_contains "${COMMAND_OUTPUT}" "eni-03c6a627c2ce46d98 subnet=subnet-03085888abd0f7244 groups=sg-0f9c872d13021f5ef" "down diagnostics should include the orphaned ENI details"
  assert_contains "${COMMAND_OUTPUT}" "delete candidate: aws ec2 delete-network-interface --region us-west-2 --network-interface-id eni-03c6a627c2ce46d98" "down diagnostics should print the manual ENI cleanup command"

  AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")
  assert_contains "${AWS_LOG}" "ec2 describe-network-interfaces --region us-west-2 --filters Name=vpc-id,Values=vpc-12345 Name=status,Values=available" "down should query available ENIs in the VPC when destroy fails"
  teardown_test_tmpdir
}

run_down_orphan_eni_cleanup_retry_test() {
  setup_test_tmpdir
  write_common_down_stubs
  write_successful_down_kubectl_stub

  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/terraform.log\"" \
"if [[ \"\$2\" == 'destroy' ]]; then" \
"  attempts_file='${TEST_TMPDIR}/destroy-attempts'" \
"  attempts=0" \
"  if [[ -f \"\${attempts_file}\" ]]; then" \
"    attempts=\$(cat \"\${attempts_file}\")" \
"  fi" \
"  attempts=\$((attempts + 1))" \
"  printf '%s\n' \"\${attempts}\" > \"\${attempts_file}\"" \
"  if [[ \"\${attempts}\" == '1' ]]; then" \
"    exit 1" \
"  fi" \
"  exit 0" \
"fi" \
"case \"\$2\" in" \
"  init) exit 0 ;;" \
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
"  'ec2 describe-network-interfaces')" \
"    printf '%s\t%s\t%s\t%s\t%s\n' 'eni-03c6a627c2ce46d98' 'aws-K8S-i-0f9e65492af4c27fb' 'subnet-03085888abd0f7244' 'sg-0f9c872d13021f5ef' 'AROATBRKPOLXETKDLLAAM:eks-gpu-infere-aws-node-c-c810c7b3-5f72-4719-b476-c634ee062d4e'" \
"    printf '%s\t%s\t%s\t%s\t%s\n' 'eni-09999999999999999' 'manual-debug-eni' 'subnet-09999999999999999' 'sg-0123456789abcdef0' 'None'" \
"    exit 0" \
"    ;;" \
"  'ec2 delete-network-interface')" \
"    printf '%s\n' \"\$6\" >> \"${TEST_TMPDIR}/deleted-enis.log\"" \
"    exit 0" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/down" --cleanup-orphan-enis -auto-approve

  assert_status 0 "${COMMAND_STATUS}" "down should recover from orphan aws-K8S ENIs when cleanup is enabled"
  assert_contains "${COMMAND_OUTPUT}" "terraform destroy failed; checking for cleanup-eligible orphan aws-K8S ENIs." "down should explain the cleanup retry path"
  assert_contains "${COMMAND_OUTPUT}" "cleanup eligible: yes" "down diagnostics should mark the orphan aws-K8S ENI as cleanup eligible"
  assert_contains "${COMMAND_OUTPUT}" "cleanup eligible: no" "down diagnostics should leave unrelated ENIs out of automatic cleanup"
  assert_contains "${COMMAND_OUTPUT}" "deleted 1 cleanup-eligible orphan aws-K8S ENI(s)." "down should report the automatic ENI cleanup count"
  assert_contains "${COMMAND_OUTPUT}" "Retrying terraform destroy after orphan ENI cleanup..." "down should retry terraform destroy after deleting orphan ENIs"
  assert_contains "${COMMAND_OUTPUT}" "OK 8/8 terraform destroy" "down should finish successfully after cleanup and retry"

  TERRAFORM_LOG=$(cat "${TEST_TMPDIR}/terraform.log")
  AWS_LOG=$(cat "${TEST_TMPDIR}/aws.log")
  DELETED_ENIS=$(cat "${TEST_TMPDIR}/deleted-enis.log")
  DESTROY_COUNT=$(printf '%s\n' "${TERRAFORM_LOG}" | awk 'index($0, "destroy -auto-approve") { count++ } END { print count + 0 }')

  assert_eq "2" "${DESTROY_COUNT}" "down should invoke terraform destroy twice around orphan ENI cleanup"
  assert_not_contains "${TERRAFORM_LOG}" "destroy --cleanup-orphan-enis -auto-approve" "down should not pass the cleanup flag through to terraform destroy during retry"
  assert_contains "${AWS_LOG}" "ec2 delete-network-interface --region us-west-2 --network-interface-id eni-03c6a627c2ce46d98" "down should delete the cleanup-eligible aws-K8S ENI"
  assert_not_contains "${AWS_LOG}" "ec2 delete-network-interface --region us-west-2 --network-interface-id eni-09999999999999999" "down should not delete unrelated available ENIs automatically"
  assert_contains "${DELETED_ENIS}" "eni-03c6a627c2ce46d98" "down should record the cleanup-eligible ENI deletion"
  teardown_test_tmpdir
}

run_missing_prereq_test
run_up_ingress_timeout_test
run_verify_gpu_timeout_test
run_verify_ready_timeout_test
run_verify_response_timeout_test
run_evaluate_warm_profile_capacity_timeout_test
run_evaluate_compare_warm_profile_capacity_timeout_test
run_evaluate_metric_pipeline_timeout_test
run_evaluate_active_pressure_metric_pipeline_timeout_test
run_evaluate_scale_out_timeout_test
run_evaluate_compare_second_policy_failure_test
run_evaluate_sweep_second_target_failure_test
run_down_alb_timeout_test
run_down_cluster_unreachable_test
run_down_destroy_dependency_diagnostics_test
run_down_orphan_eni_cleanup_retry_test
