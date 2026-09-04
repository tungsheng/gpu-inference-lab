#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

run_kv_observe_demo_test() {
  setup_test_tmpdir

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" demo \
    --output "${TEST_TMPDIR}/demo.html" \
    --trace "${TEST_TMPDIR}/demo-trace.json"

  assert_status 0 "${COMMAND_STATUS}" "kv-observe demo should render a local timeline"
  assert_file_exists "${TEST_TMPDIR}/demo.html" "kv-observe demo should write HTML"
  assert_file_exists "${TEST_TMPDIR}/demo-trace.json" "kv-observe demo should write a trace artifact"

  DEMO_HTML=$(cat "${TEST_TMPDIR}/demo.html")
  DEMO_TRACE=$(cat "${TEST_TMPDIR}/demo-trace.json")

  assert_contains "${DEMO_HTML}" "KV Cache Observatory" "demo HTML should title the observatory"
  assert_contains "${DEMO_HTML}" "Request A" "demo HTML should render Request A"
  assert_contains "${DEMO_HTML}" "Request B" "demo HTML should render Request B"
  assert_contains "${DEMO_HTML}" "Request C" "demo HTML should render Request C"
  assert_contains "${DEMO_TRACE}" "\"schema_version\": \"kv-cache-trace/v1\"" "demo trace should use the trace contract"
  assert_contains "${DEMO_TRACE}" "\"type\": \"block_reused\"" "demo trace should include cache reuse events"
  assert_contains "${DEMO_TRACE}" "\"cache_hit_blocks\": 5" "demo trace summary should count reused blocks"

  teardown_test_tmpdir
}

run_kv_observe_demo_default_output_test() {
  setup_test_tmpdir

  DEFAULT_DEMO_OUTPUT="/tmp/kv-cache-observatory.html"
  rm -f "${DEFAULT_DEMO_OUTPUT}"

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" demo

  assert_status 0 "${COMMAND_STATUS}" "kv-observe demo should work with its default output path"
  assert_file_exists "${DEFAULT_DEMO_OUTPUT}" "kv-observe demo should write its default HTML artifact"

  rm -f "${DEFAULT_DEMO_OUTPUT}"
  teardown_test_tmpdir
}

run_kv_observe_render_test() {
  setup_test_tmpdir

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" demo \
    --output "${TEST_TMPDIR}/demo.html" \
    --trace "${TEST_TMPDIR}/demo-trace.json"
  assert_status 0 "${COMMAND_STATUS}" "kv-observe demo should prepare a trace for rendering"

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" render \
    --input "${TEST_TMPDIR}/demo-trace.json" \
    --output "${TEST_TMPDIR}/demo.svg" \
    --format svg

  assert_status 0 "${COMMAND_STATUS}" "kv-observe render should render SVG from a trace"
  assert_file_exists "${TEST_TMPDIR}/demo.svg" "kv-observe render should write SVG"

  DEMO_SVG=$(cat "${TEST_TMPDIR}/demo.svg")
  assert_contains "${DEMO_SVG}" "<svg" "rendered output should be SVG"
  assert_contains "${DEMO_SVG}" "KV Cache Observatory Timeline" "rendered SVG should include the timeline title"
  assert_contains "${DEMO_SVG}" "reused" "rendered SVG should include the reuse legend"

  teardown_test_tmpdir
}

run_kv_observe_normalize_events_test() {
  setup_test_tmpdir

  printf '%s\n' \
    '[{"type":"BlockStored","request_id":"request-a","block_hashes":[11,12],"time_seconds":1},{"type":"BlockRemoved","request_id":"request-a","block_hashes":[11],"time_seconds":2}]' \
    > "${TEST_TMPDIR}/events.json"

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" normalize-events \
    --input "${TEST_TMPDIR}/events.json" \
    --output "${TEST_TMPDIR}/trace.json" \
    --total-blocks 4

  assert_status 0 "${COMMAND_STATUS}" "kv-observe normalize-events should normalize vLLM-like events"
  assert_file_exists "${TEST_TMPDIR}/trace.json" "normalize-events should write a trace artifact"

  NORMALIZED_TRACE=$(cat "${TEST_TMPDIR}/trace.json")
  assert_contains "${NORMALIZED_TRACE}" "\"schema_version\": \"kv-cache-trace/v1\"" "normalized trace should use the trace contract"
  assert_contains "${NORMALIZED_TRACE}" "\"type\": \"block_allocated\"" "normalized trace should include allocations"
  assert_contains "${NORMALIZED_TRACE}" "\"type\": \"block_evicted\"" "normalized trace should include evictions"
  assert_contains "${NORMALIZED_TRACE}" "\"id\": \"request-a\"" "normalized trace should preserve request ids in the request list"
  assert_contains "${NORMALIZED_TRACE}" "\"source\": \"observed\"" "normalized trace should preserve observed source labels"
  assert_contains "${NORMALIZED_TRACE}" "\"active_blocks\": 1" "normalized summary should count active blocks"
  assert_contains "${NORMALIZED_TRACE}" "\"free_blocks\": 3" "normalized summary should count free blocks"
  assert_contains "${NORMALIZED_TRACE}" "\"evictions\": 1" "normalized summary should count evicted blocks"

  teardown_test_tmpdir
}

run_kv_observe_preflight_test() {
  run_and_capture "${REPO_ROOT}/scripts/kv-observe" preflight \
    --experiment kv-cache-observatory \
    --profile modern-vllm-0221

  assert_status 0 "${COMMAND_STATUS}" "kv-observe preflight should accept the modern vLLM profile"
  assert_contains "${COMMAND_OUTPUT}" "OK kv-cache-observatory/modern-vllm-0221 uses vllm/vllm-openai:v0.22.1" "preflight should report the pinned vLLM image"

  run_and_capture "${REPO_ROOT}/scripts/kv-observe" preflight \
    --experiment kv-cache-observatory \
    --profile default

  assert_status 1 "${COMMAND_STATUS}" "kv-observe preflight should reject the historical default profile"
  assert_contains "${COMMAND_OUTPUT}" "Expected a vllm/vllm-openai:v0.22.1 image" "preflight should explain profile version mismatch"
  assert_contains "${COMMAND_OUTPUT}" "found: vllm/vllm-openai:v0.9.0" "preflight should name the image it actually found"
}

run_kv_observe_demo_test
run_kv_observe_demo_default_output_test
run_kv_observe_render_test
run_kv_observe_normalize_events_test
run_kv_observe_preflight_test
