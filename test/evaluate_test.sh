#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

write_evaluate_kubectl_stub() {
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
"  'delete -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/warm-placeholder-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete hpa vllm-openai -n app --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/hpa-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-applied\"" \
"    exit 0" \
"    ;;" \
"  'delete -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-warm.yaml --ignore-not-found=true') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml')" \
"    : > \"${TEST_TMPDIR}/warm-placeholder-applied\"" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" || -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'node/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" || -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
"      printf '%s\n' 'nodeclaim/gpu-serving-1'" \
"      if [[ -f \"${TEST_TMPDIR}/load-applied\" || -f \"${TEST_TMPDIR}/load-finished\" ]]; then" \
"        printf '%s\n' 'nodeclaim/gpu-serving-2'" \
"      fi" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'get nodes -l workload=gpu --sort-by=.metadata.creationTimestamp -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-applied\" || -f \"${TEST_TMPDIR}/warm-placeholder-applied\" ]]; then" \
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
"    printf '%s\n' '${REPO_ROOT}/platform/inference/hpa.yaml' > \"${TEST_TMPDIR}/applied-hpa-path.txt\"" \
"    exit 0" \
"    ;;" \
"  apply\ -f\ /tmp/gpu-lab-active-hpa.*)" \
"    : > \"${TEST_TMPDIR}/hpa-applied\"" \
"    printf '%s\n' \"\$3\" > \"${TEST_TMPDIR}/applied-hpa-path.txt\"" \
"    cp \"\$3\" \"${TEST_TMPDIR}/applied-active-hpa.yaml\"" \
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
"  'rollout status deployment/gpu-warm-placeholder -n app --timeout=1200s') exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running') printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"256\"}]}'; exit 0 ;;" \
"  'get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active') printf '%s\n' '{\"kind\":\"MetricValueList\",\"items\":[{\"value\":\"320\"}]}'; exit 0 ;;" \
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
}

write_evaluate_curl_stub() {
  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
"cmd=\"\$*\"" \
"if [[ \"\$cmd\" == *'/api/v1/query'* ]]; then" \
"  value='1.25'" \
"  if [[ \"\$cmd\" == *'num_requests_waiting'* && \"\$cmd\" == *'e2e_request_latency_seconds_count'* ]]; then" \
"    value='0.420'" \
"  elif [[ \"\$cmd\" == *'e2e_request_latency_seconds_count'* ]]; then" \
"    value='18.0'" \
"  elif [[ \"\$cmd\" == *'sum(vllm:num_requests_running'* && \"\$cmd\" == *'sum(vllm:num_requests_waiting'* ]]; then" \
"    value='320'" \
"  elif [[ \"\$cmd\" == *'num_requests_waiting'* ]]; then" \
"    value='64'" \
"  elif [[ \"\$cmd\" == *'time_to_first_token_seconds_bucket'* ]]; then" \
"    value='0.61'" \
"  elif [[ \"\$cmd\" == *'num_requests_running'* ]]; then" \
"    value='256'" \
"  elif [[ \"\$cmd\" == *'generation_tokens_total'* ]]; then" \
"    value='142.5'" \
"  elif [[ \"\$cmd\" == *'avg_over_time((avg(DCGM_FI_DEV_GPU_UTIL))'* ]]; then" \
"    value='74.2'" \
"  elif [[ \"\$cmd\" == *'max_over_time((max(DCGM_FI_DEV_GPU_UTIL))'* ]]; then" \
"    value='93.7'" \
"  elif [[ \"\$cmd\" == *'karpenter_nodeclaims_created_total'* ]]; then" \
"    value='2'" \
"  fi" \
"  printf '{\"status\":\"success\",\"data\":{\"resultType\":\"vector\",\"result\":[{\"metric\":{},\"value\":[1712781000,\"%s\"]}]}}' \"\$value\"" \
"  exit 0" \
"fi" \
"if [[ \"\$cmd\" == *'--data-binary @'* ]]; then" \
"  exit 0" \
"fi" \
"printf '200'"
}

run_running_policy_test() {
  setup_test_tmpdir
  write_evaluate_kubectl_stub
  write_evaluate_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" \
    --profile zero-idle \
    --report "${TEST_TMPDIR}/report.md" \
    --json-report "${TEST_TMPDIR}/report.json"

  assert_status 0 "${COMMAND_STATUS}" "scripts/evaluate should complete the running-policy workflow by default"
  assert_contains "${COMMAND_OUTPUT}" "OK 5/10 wait for hpa metric pipeline and apply hpa" "running policy should keep the original stage label"
  assert_contains "${COMMAND_OUTPUT}" "Policy: running" "running policy output should print the selected policy"
  assert_contains "${COMMAND_OUTPUT}" "HPA metric: vllm_requests_running" "running policy output should print the running metric"
  assert_contains "${COMMAND_OUTPUT}" "Markdown report: ${TEST_TMPDIR}/report.md" "running policy should print the Markdown report path"

  assert_file_exists "${TEST_TMPDIR}/report.md" "running policy should write the Markdown report"
  assert_file_exists "${TEST_TMPDIR}/report.json" "running policy should write the JSON report"

  REPORT_CONTENT=$(cat "${TEST_TMPDIR}/report.md")
  JSON_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/report.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")

  assert_contains "${REPORT_CONTENT}" "Policy: running" "the Markdown report should include the policy metadata"
  assert_contains "${REPORT_CONTENT}" "HPA metric name: vllm_requests_running" "the Markdown report should include the running metric name"
  assert_contains "${REPORT_CONTENT}" "HPA target average value: 128" "the Markdown report should include the running metric target"
  assert_contains "${REPORT_CONTENT}" "p95 estimated queue wait during burst" "the Markdown report should include the derived queue-wait estimate"
  assert_contains "${REPORT_CONTENT}" "Peak active requests per active GPU node" "the Markdown report should include the per-GPU active-request readout"
  assert_contains "${REPORT_CONTENT}" "Capacity assessment: balanced" "the Markdown report should summarize the capacity assessment"
  assert_contains "${REPORT_CONTENT}" "Peak waiting requests" "the Markdown report should include peak waiting requests"
  assert_contains "${REPORT_CONTENT}" "Peak active requests" "the Markdown report should include peak active requests"
  assert_contains "${JSON_REPORT_CONTENT}" "\"policy\": \"running\"" "the JSON report should include the running policy"
  assert_contains "${JSON_REPORT_CONTENT}" "\"hpa_metric_name\": \"vllm_requests_running\"" "the JSON report should include the running metric name"
  assert_contains "${JSON_REPORT_CONTENT}" "\"hpa_target_average_value\": \"128\"" "the JSON report should include the running target"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p95_estimated_queue_wait_seconds\": 0.420" "the JSON report should include the derived queue-wait estimate"
  assert_contains "${JSON_REPORT_CONTENT}" "\"peak_active_requests_per_gpu_node\": 160.000" "the JSON report should include the per-GPU active-request readout"
  assert_contains "${JSON_REPORT_CONTENT}" "\"status\": \"balanced\"" "the JSON report should include the capacity assessment status"
  assert_contains "${JSON_REPORT_CONTENT}" "\"peak_waiting_requests\": 64" "the JSON report should include peak waiting requests"
  assert_contains "${JSON_REPORT_CONTENT}" "\"peak_active_requests\": 320" "the JSON report should include peak active requests"
  assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/inference/hpa.yaml" "running policy should apply the checked-in running HPA"
  assert_contains "${KUBECTL_LOG}" "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" "running policy should preflight the running metric"
  assert_occurs_before "${KUBECTL_LOG}" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" \
    "apply -f ${REPO_ROOT}/platform/inference/hpa.yaml" \
    "running policy should wait for the running metric before applying the HPA"
  assert_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/running/target/128" "running policy should push summary metrics with policy and target labels in the Pushgateway path"

  teardown_test_tmpdir
}

run_active_pressure_policy_test() {
  setup_test_tmpdir
  write_evaluate_kubectl_stub
  write_evaluate_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" \
    --profile zero-idle \
    --policy active-pressure \
    --active-target 6 \
    --report "${TEST_TMPDIR}/active.md" \
    --json-report "${TEST_TMPDIR}/active.json"

  assert_status 0 "${COMMAND_STATUS}" "scripts/evaluate should complete the active-pressure workflow"
  assert_contains "${COMMAND_OUTPUT}" "OK 5/10 active-pressure: wait for hpa metric pipeline and apply hpa" "active-pressure should prefix the stage label"
  assert_contains "${COMMAND_OUTPUT}" "Policy: active-pressure" "active-pressure output should print the selected policy"
  assert_contains "${COMMAND_OUTPUT}" "HPA metric: vllm_requests_active" "active-pressure output should print the active metric"
  assert_contains "${COMMAND_OUTPUT}" "HPA target average value: 6" "active-pressure output should print the overridden target"

  assert_file_exists "${TEST_TMPDIR}/active.md" "active-pressure should write the Markdown report"
  assert_file_exists "${TEST_TMPDIR}/active.json" "active-pressure should write the JSON report"
  assert_file_exists "${TEST_TMPDIR}/applied-active-hpa.yaml" "active-pressure should render a temporary HPA manifest when the target is overridden"

  REPORT_CONTENT=$(cat "${TEST_TMPDIR}/active.md")
  JSON_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/active.json")
  APPLIED_ACTIVE_HPA_CONTENT=$(cat "${TEST_TMPDIR}/applied-active-hpa.yaml")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")

  assert_contains "${REPORT_CONTENT}" "Policy: active-pressure" "the Markdown report should include the active-pressure policy"
  assert_contains "${REPORT_CONTENT}" "HPA metric name: vllm_requests_active" "the Markdown report should include the active metric name"
  assert_contains "${REPORT_CONTENT}" "HPA target average value: 6" "the Markdown report should include the overridden active target"
  assert_contains "${REPORT_CONTENT}" "Capacity assessment: saturated" "the Markdown report should call out the saturated active-pressure run"
  assert_contains "${JSON_REPORT_CONTENT}" "\"policy\": \"active-pressure\"" "the JSON report should include the active-pressure policy"
  assert_contains "${JSON_REPORT_CONTENT}" "\"hpa_metric_name\": \"vllm_requests_active\"" "the JSON report should include the active metric name"
  assert_contains "${JSON_REPORT_CONTENT}" "\"hpa_target_average_value\": \"6\"" "the JSON report should include the overridden active target"
  assert_contains "${JSON_REPORT_CONTENT}" "\"p95_estimated_queue_wait_seconds\": 0.420" "the JSON report should include the derived queue-wait estimate"
  assert_contains "${JSON_REPORT_CONTENT}" "\"status\": \"saturated\"" "the JSON report should include the capacity assessment status"
  assert_contains "${APPLIED_ACTIVE_HPA_CONTENT}" "name: vllm_requests_active" "the rendered HPA manifest should target the active metric"
  assert_contains "${APPLIED_ACTIVE_HPA_CONTENT}" "averageValue: \"6\"" "the rendered HPA manifest should include the overridden target"
  assert_contains "${KUBECTL_LOG}" "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" "active-pressure should preflight the active metric"
  assert_contains "${KUBECTL_LOG}" "apply -f /tmp/gpu-lab-active-hpa." "active-pressure should apply the rendered HPA manifest"
  assert_occurs_before "${KUBECTL_LOG}" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" \
    "apply -f /tmp/gpu-lab-active-hpa." \
    "active-pressure should wait for the active metric before applying the rendered HPA"
  assert_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/active-pressure/target/6" "active-pressure should push summary metrics with policy and target labels in the Pushgateway path"

  teardown_test_tmpdir
}

run_compare_policy_test() {
  setup_test_tmpdir
  write_evaluate_kubectl_stub
  write_evaluate_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" \
    --profile warm-1 \
    --policy compare \
    --active-target 6 \
    --report "${TEST_TMPDIR}/compare.md" \
    --json-report "${TEST_TMPDIR}/compare.json"

  assert_status 0 "${COMMAND_STATUS}" "scripts/evaluate should complete the compare workflow"
  assert_contains "${COMMAND_OUTPUT}" "OK 1/10 running: checking prerequisites" "compare mode should prefix the running-policy stages"
  assert_contains "${COMMAND_OUTPUT}" "OK 1/10 active-pressure: checking prerequisites" "compare mode should run the active-pressure stages after running"
  assert_contains "${COMMAND_OUTPUT}" "Compared:" "compare mode should print a compare summary"
  assert_contains "${COMMAND_OUTPUT}" "Compare report: ${TEST_TMPDIR}/compare-compare.md" "compare mode should print the compare Markdown report path"

  assert_file_exists "${TEST_TMPDIR}/compare-running.md" "compare mode should write the running-policy Markdown report"
  assert_file_exists "${TEST_TMPDIR}/compare-running.json" "compare mode should write the running-policy JSON report"
  assert_file_exists "${TEST_TMPDIR}/compare-active-pressure.md" "compare mode should write the active-pressure Markdown report"
  assert_file_exists "${TEST_TMPDIR}/compare-active-pressure.json" "compare mode should write the active-pressure JSON report"
  assert_file_exists "${TEST_TMPDIR}/compare-compare.md" "compare mode should write the compare Markdown report"
  assert_file_exists "${TEST_TMPDIR}/compare-compare.json" "compare mode should write the compare JSON report"

  COMPARE_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/compare-compare.md")
  COMPARE_JSON_CONTENT=$(cat "${TEST_TMPDIR}/compare-compare.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")

  assert_contains "${COMPARE_REPORT_CONTENT}" "| p95 request latency |" "the compare report should include the side-by-side metric table"
  assert_contains "${COMPARE_REPORT_CONTENT}" "| p95 estimated queue wait |" "the compare report should include the derived queue-wait row"
  assert_contains "${COMPARE_REPORT_CONTENT}" "| running | vllm_requests_running | 128 |" "the compare report should include the running policy settings"
  assert_contains "${COMPARE_REPORT_CONTENT}" "| active-pressure | vllm_requests_active | 6 |" "the compare report should include the active-pressure settings"
  assert_contains "${COMPARE_REPORT_CONTENT}" "| Capacity assessment | balanced | saturated |" "the compare report should compare the efficiency assessment"
  assert_contains "${COMPARE_JSON_CONTENT}" "\"running\":" "the compare JSON report should include the running section"
  assert_contains "${COMPARE_JSON_CONTENT}" "\"active_pressure\":" "the compare JSON report should include the active-pressure section"
  assert_contains "${COMPARE_JSON_CONTENT}" "\"p95_estimated_queue_wait_seconds\": 0.420" "the compare JSON report should include the derived queue-wait estimate"
  assert_occurs_before "${KUBECTL_LOG}" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_running" \
    "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" \
    "compare mode should execute the running policy before the active-pressure policy"
  assert_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/warm-1/policy/running/target/128" "compare mode should push running-policy summary metrics with policy and target labels"
  assert_contains "${CURL_LOG}" "/metrics/job/gpu-serving-measure/profile/warm-1/policy/active-pressure/target/6" "compare mode should push active-pressure summary metrics with policy and target labels"

  WARM_PLACEHOLDER_APPLY_COUNT=$(printf '%s\n' "${KUBECTL_LOG}" | awk -v needle="apply -f ${REPO_ROOT}/platform/tests/gpu-warm-placeholder.yaml" 'index($0, needle) { count++ } END { print count + 0 }')
  assert_eq "2" "${WARM_PLACEHOLDER_APPLY_COUNT}" "compare mode should restore the warm baseline for both policy runs"

  teardown_test_tmpdir
}

run_sweep_policy_test() {
  setup_test_tmpdir
  write_evaluate_kubectl_stub
  write_evaluate_curl_stub

  run_and_capture env \
    PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR=/tmp \
    /bin/bash "${REPO_ROOT}/scripts/evaluate" \
    --profile zero-idle \
    --policy sweep \
    --active-targets 2,4,8 \
    --report "${TEST_TMPDIR}/sweep.md" \
    --json-report "${TEST_TMPDIR}/sweep.json"

  assert_status 0 "${COMMAND_STATUS}" "scripts/evaluate should complete the sweep workflow"
  assert_contains "${COMMAND_OUTPUT}" "OK 1/10 active-pressure@2: checking prerequisites" "sweep mode should prefix stages with the first target"
  assert_contains "${COMMAND_OUTPUT}" "OK 1/10 active-pressure@8: checking prerequisites" "sweep mode should execute later active targets in order"
  assert_contains "${COMMAND_OUTPUT}" "Swept:" "sweep mode should print a sweep summary"
  assert_contains "${COMMAND_OUTPUT}" "Recommended active target: 8" "sweep mode should print the recommended target"
  assert_contains "${COMMAND_OUTPUT}" "Sweep report: ${TEST_TMPDIR}/sweep-active-pressure-sweep.md" "sweep mode should print the sweep Markdown report path"

  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-2.md" "sweep mode should write the target-2 Markdown report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-2.json" "sweep mode should write the target-2 JSON report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-4.md" "sweep mode should write the target-4 Markdown report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-4.json" "sweep mode should write the target-4 JSON report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-8.md" "sweep mode should write the target-8 Markdown report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-target-8.json" "sweep mode should write the target-8 JSON report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-sweep.md" "sweep mode should write the sweep Markdown report"
  assert_file_exists "${TEST_TMPDIR}/sweep-active-pressure-sweep.json" "sweep mode should write the sweep JSON report"

  SWEEP_REPORT_CONTENT=$(cat "${TEST_TMPDIR}/sweep-active-pressure-sweep.md")
  SWEEP_JSON_CONTENT=$(cat "${TEST_TMPDIR}/sweep-active-pressure-sweep.json")
  KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
  CURL_LOG=$(cat "${TEST_TMPDIR}/curl.log")

  assert_contains "${SWEEP_REPORT_CONTENT}" "| Active target | Status |" "the sweep report should include the per-target summary table"
  assert_contains "${SWEEP_REPORT_CONTENT}" "p95 estimated queue wait" "the sweep report should include the derived queue-wait column"
  assert_contains "${SWEEP_REPORT_CONTENT}" "| 2 | saturated |" "the sweep report should include the first evaluated target"
  assert_contains "${SWEEP_REPORT_CONTENT}" "| 8 | saturated |" "the sweep report should include the last evaluated target"
  assert_contains "${SWEEP_REPORT_CONTENT}" "Recommended active target: 8" "the sweep report should include the recommended target"
  assert_contains "${SWEEP_REPORT_CONTENT}" "## Target Interpretation" "the sweep report should explain why each target looked efficient or wasteful"
  assert_contains "${SWEEP_JSON_CONTENT}" "\"mode\": \"sweep\"" "the sweep JSON report should mark the sweep mode"
  assert_contains "${SWEEP_JSON_CONTENT}" "\"active_target\": 8" "the sweep JSON report should include the recommended target"
  assert_contains "${SWEEP_JSON_CONTENT}" "\"active_target\": 2" "the sweep JSON report should include the first target result"
  assert_contains "${SWEEP_JSON_CONTENT}" "\"active_target\": 4" "the sweep JSON report should include the second target result"
  assert_contains "${SWEEP_JSON_CONTENT}" "\"p95_estimated_queue_wait_seconds\": 0.420" "the sweep JSON report should include the derived queue-wait estimate"
  assert_contains "${KUBECTL_LOG}" "get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/app/pods/vllm-openai-0/vllm_requests_active" "sweep mode should preflight the active metric"
  assert_occurs_before "${CURL_LOG}" \
    "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/active-pressure/target/2" \
    "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/active-pressure/target/4" \
    "sweep mode should push target-2 metrics before target-4 metrics"
  assert_occurs_before "${CURL_LOG}" \
    "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/active-pressure/target/4" \
    "/metrics/job/gpu-serving-measure/profile/zero-idle/policy/active-pressure/target/8" \
    "sweep mode should push target-4 metrics before target-8 metrics"

  teardown_test_tmpdir
}

run_running_policy_test
run_active_pressure_policy_test
run_compare_policy_test
run_sweep_policy_test
