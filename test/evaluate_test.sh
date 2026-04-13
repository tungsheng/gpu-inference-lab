#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

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
"  'delete -f ${REPO_ROOT}/platform/inference/hpa.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/warm-nodepool\"" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" ]]; then" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'node/gpu-serving-1'" \
"        printf '%s\n' 'node/gpu-serving-2'" \
"      else" \
"        printf '%s\n' 'node/gpu-serving-1'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -o name')" \
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
"  'get node gpu-serving-2 -o jsonpath={.metadata.labels.node\.kubernetes\.io/instance-type}') printf '%s\n' 'g4dn.xlarge'; exit 0 ;;" \
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
  "  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running') printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"0\"}]}'; exit 0 ;;" \
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
"  *) printf 'unexpected kubectl command: %s\n' \"\$cmd\" >&2; exit 1 ;;" \
"esac"

write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  value='1.25'" \
"  case \"\$cmd\" in" \
"    *'time_to_first_token_seconds_bucket'*) value='0.61' ;;" \
"    *'num_requests_running'*) value='256' ;;" \
"    *'generation_tokens_total'*) value='142.5' ;;" \
"    *'avg_over_time((avg(DCGM_FI_DEV_GPU_UTIL))'*) value='74.2' ;;" \
"    *'max_over_time((max(DCGM_FI_DEV_GPU_UTIL))'*) value='93.7' ;;" \
"    *'karpenter_nodeclaims_created_total'*) value='2' ;;" \
"  esac" \
"  printf '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"%s\"]}]}}' \"\$value\"" \
"  exit 0" \
"fi" \
"if [[ \"\$cmd\" == *'--data-binary @'* ]]; then" \
"  exit 0" \
"fi" \
"printf '200'"

run_and_capture env \
  PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/bash "${REPO_ROOT}/scripts/evaluate" \
  --profile zero-idle \
  --report "${TEST_TMPDIR}/report.md" \
  --json-report "${TEST_TMPDIR}/report.json"

assert_status 0 "${COMMAND_STATUS}" "scripts/evaluate should complete the load-aware validation flow"
assert_contains "${COMMAND_OUTPUT}" "OK 5/10 wait for hpa metric pipeline and apply hpa" "evaluate should confirm the metric preflight stage"
assert_contains "${COMMAND_OUTPUT}" "OK 6/10 run load and wait for scale-out" "evaluate should confirm the scale-out stage"
assert_contains "${COMMAND_OUTPUT}" "OK 10/10 collect metrics and write reports" "evaluate should collect metrics and write reports"
assert_contains "${COMMAND_OUTPUT}" "Profile: zero-idle" "evaluate should summarize the profile it measured"
assert_contains "${COMMAND_OUTPUT}" "Markdown report: ${TEST_TMPDIR}/report.md" "evaluate should print the Markdown report path"

assert_file_exists "${TEST_TMPDIR}/report.md" "evaluate should write the Markdown report"
assert_file_exists "${TEST_TMPDIR}/report.json" "evaluate should write the JSON report"

REPORT_CONTENT=$(cat "${TEST_TMPDIR}/report.md")
KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")

assert_contains "${REPORT_CONTENT}" "Second GPU node" "the report should include the scale-out timeline"
assert_contains "${REPORT_CONTENT}" "Average GPU utilization" "the report should include Prometheus-backed GPU metrics"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/inference/hpa.yaml" "evaluate should apply the HPA manifest"
assert_contains "${KUBECTL_LOG}" "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" "evaluate should verify that the custom metric is available before running load"
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml" "evaluate should apply the load test manifest"
assert_occurs_before "${KUBECTL_LOG}" \
  "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" \
  "apply -f ${REPO_ROOT}/platform/inference/hpa.yaml" \
  "evaluate should wait for the custom metric before applying the HPA"
assert_occurs_before "${KUBECTL_LOG}" \
  "apply -f ${REPO_ROOT}/platform/inference/hpa.yaml" \
  "apply -f ${REPO_ROOT}/platform/tests/gpu-load-test.yaml" \
  "evaluate should apply the HPA before starting the burst load"
