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
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
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
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
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
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true') exit 0 ;;" \
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

run_missing_prereq_test
run_up_ingress_timeout_test
run_verify_gpu_timeout_test
run_verify_ready_timeout_test
run_verify_response_timeout_test
run_evaluate_warm_profile_capacity_timeout_test
run_evaluate_metric_pipeline_timeout_test
run_evaluate_scale_out_timeout_test
run_down_alb_timeout_test
run_down_cluster_unreachable_test
