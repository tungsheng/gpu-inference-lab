#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

TEST_PATH_SUFFIX="/usr/bin:/bin:/usr/sbin:/sbin"

run_failure_list_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" list

  assert_status 0 "${COMMAND_STATUS}" "failure list should succeed"
  assert_contains "${COMMAND_OUTPUT}" "Scenarios:" "failure list should show scenarios"
  assert_contains "${COMMAND_OUTPUT}" "spot-interruption" "failure list should include spot interruption"
  assert_contains "${COMMAND_OUTPUT}" "vllm-pod-delete" "failure list should include pod deletion"
  assert_contains "${COMMAND_OUTPUT}" "Mitigations:" "failure list should show mitigations"
  assert_contains "${COMMAND_OUTPUT}" "bounded-admission" "failure list should include bounded admission"
  assert_contains "${COMMAND_OUTPUT}" "Suites:" "failure list should show suites"
  assert_contains "${COMMAND_OUTPUT}" "capacity-recovery" "failure list should include the capacity suite"
}

run_failure_show_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" show scenario spot-interruption

  assert_status 0 "${COMMAND_STATUS}" "failure show should succeed for a scenario"
  assert_contains "${COMMAND_OUTPUT}" "Scenario: spot-interruption" "show should include the scenario id"
  assert_contains "${COMMAND_OUTPUT}" "Runner: evaluate-resilience" "show should include the scenario runner"
  assert_contains "${COMMAND_OUTPUT}" "Recovery gate: replacement-gpu-node-and-two-ready-replicas" "show should include the recovery gate"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" show mitigation ondemand-fallback

  assert_status 0 "${COMMAND_STATUS}" "failure show should succeed for a mitigation"
  assert_contains "${COMMAND_OUTPUT}" "Mitigation: ondemand-fallback" "show should include the mitigation id"
  assert_contains "${COMMAND_OUTPUT}" "Policy: active-pressure" "show should include the policy"

  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" show suite capacity-recovery

  assert_status 0 "${COMMAND_STATUS}" "failure show should succeed for a suite"
  assert_contains "${COMMAND_OUTPUT}" "scenario=spot-unavailable" "suite output should include spot unavailable"
  assert_contains "${COMMAND_OUTPUT}" "scenario=spot-interruption" "suite output should include spot interruption"
}

run_failure_dry_run_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" run \
    --scenario spot-interruption \
    --mitigation ondemand-fallback \
    --run-id test-run \
    --dry-run

  assert_status 0 "${COMMAND_STATUS}" "failure run dry-run should succeed"
  assert_contains "${COMMAND_OUTPUT}" "Failure drill plan" "dry-run should print a plan"
  assert_contains "${COMMAND_OUTPUT}" "--resilience spot-interruption" "dry-run should render the evaluate resilience mode"
  assert_contains "${COMMAND_OUTPUT}" "--policy active-pressure" "dry-run should render the mitigation policy"
  assert_contains "${COMMAND_OUTPUT}" "failure-spot-interruption-ondemand-fallback-test-run.md" "dry-run should render deterministic report paths"
  assert_contains "${COMMAND_OUTPUT}" "Dry run: no cluster resources changed" "dry-run should not mutate resources"
}

run_failure_experiment_dry_run_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" run \
    --scenario overload-direct-vs-bounded \
    --mitigation bounded-admission \
    --run-id admission-run \
    --dry-run

  assert_status 0 "${COMMAND_STATUS}" "admission dry-run should succeed"
  assert_contains "${COMMAND_OUTPUT}" "scripts/experiment run" "admission dry-run should delegate to scripts/experiment"
  assert_contains "${COMMAND_OUTPUT}" "--experiment autoscaling" "admission dry-run should use the autoscaling experiment"
  assert_contains "${COMMAND_OUTPUT}" "--case burst-queued" "admission dry-run should use the bounded workload case"
}

run_failure_matrix_dry_run_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" matrix --suite capacity-recovery --dry-run

  assert_status 0 "${COMMAND_STATUS}" "failure matrix dry-run should succeed"
  assert_contains "${COMMAND_OUTPUT}" "scenario=spot-unavailable" "matrix should include spot unavailable"
  assert_contains "${COMMAND_OUTPUT}" "scenario=spot-interruption" "matrix should include spot interruption"
  assert_occurs_before "${COMMAND_OUTPUT}" "scenario=spot-unavailable" "scenario=spot-interruption" "capacity matrix should run spot unavailable before interruption"
}

run_failure_delegates_evaluate_test() {
  setup_test_tmpdir
  write_stub fake-evaluate \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" > \"${TEST_TMPDIR}/evaluate.args\""

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    FAILURE_EVALUATE_COMMAND="${TEST_BIN}/fake-evaluate" \
    /bin/bash "${REPO_ROOT}/scripts/failure" run \
      --scenario spot-unavailable \
      --mitigation ondemand-fallback \
      --run-id delegated-run

  assert_status 0 "${COMMAND_STATUS}" "failure run should delegate evaluate-backed scenarios"
  assert_file_exists "${TEST_TMPDIR}/evaluate.args" "evaluate delegate should be called"
  EVALUATE_ARGS=$(cat "${TEST_TMPDIR}/evaluate.args")
  assert_contains "${EVALUATE_ARGS}" "--profile zero-idle" "delegate should pass the capacity profile"
  assert_contains "${EVALUATE_ARGS}" "--policy active-pressure" "delegate should pass the HPA policy"
  assert_contains "${EVALUATE_ARGS}" "--resilience spot-unavailable" "delegate should pass the resilience mode"
  assert_contains "${EVALUATE_ARGS}" "failure-spot-unavailable-ondemand-fallback-delegated-run.md" "delegate should pass a failure report path"

  teardown_test_tmpdir
}

run_failure_cleanup_dry_run_test() {
  run_and_capture /bin/bash "${REPO_ROOT}/scripts/failure" cleanup --run-id cleanup-run --dry-run

  assert_status 0 "${COMMAND_STATUS}" "failure cleanup dry-run should succeed"
  assert_contains "${COMMAND_OUTPUT}" "Cleanup plan for run cleanup-run" "cleanup should identify the run"
  assert_contains "${COMMAND_OUTPUT}" "gpu-inference-lab/run-id=cleanup-run" "cleanup should use the run label"
}

run_failure_injector_partial_report_test() {
  setup_test_tmpdir
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"if [[ \"\$1 \$2\" == 'get pods' ]]; then" \
"  printf '%s\n' 'vllm-pod-1'" \
"  exit 0" \
"fi" \
"if [[ \"\$1 \$2 \$3\" == 'get deployment vllm-openai' ]]; then" \
"  printf '%s\n' '1'" \
"  exit 0" \
"fi" \
"if [[ \"\$1 \$2\" == 'label pod' ]]; then" \
"  exit 0" \
"fi" \
"if [[ \"\$1 \$2\" == 'delete pod' ]]; then" \
"  exit 1" \
"fi" \
"printf 'unexpected kubectl command: %s\n' \"\$*\" >&2" \
"exit 1"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' 'curl should not be called' >&2" \
"exit 1"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    /bin/bash "${REPO_ROOT}/scripts/failure" run \
      --scenario vllm-pod-delete \
      --mitigation warm-1-active-pressure \
      --run-id partial-run \
      --report "${TEST_TMPDIR}/partial.md" \
      --json-report "${TEST_TMPDIR}/partial.json"

  assert_status 1 "${COMMAND_STATUS}" "injector run should fail when the destructive command fails"
  assert_file_exists "${TEST_TMPDIR}/partial.md" "failed injector runs should still write a Markdown report"
  assert_file_exists "${TEST_TMPDIR}/partial.json" "failed injector runs should still write a JSON report"

  PARTIAL_REPORT=$(cat "${TEST_TMPDIR}/partial.md")
  PARTIAL_JSON=$(cat "${TEST_TMPDIR}/partial.json")
  assert_contains "${PARTIAL_REPORT}" "Status: failed" "partial report should mark failed status"
  assert_contains "${PARTIAL_REPORT}" "pod/vllm-pod-1" "partial report should include the target pod"
  assert_contains "${PARTIAL_JSON}" "\"status\": \"failed\"" "partial JSON report should mark failed status"
  assert_contains "${PARTIAL_JSON}" "\"outcome\": \"recovery-incomplete\"" "partial JSON should include recovery outcome"

  teardown_test_tmpdir
}

run_failure_list_test
run_failure_show_test
run_failure_dry_run_test
run_failure_experiment_dry_run_test
run_failure_matrix_dry_run_test
run_failure_delegates_evaluate_test
run_failure_cleanup_dry_run_test
run_failure_injector_partial_report_test
