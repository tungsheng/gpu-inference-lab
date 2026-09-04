#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# The catalog is reachable without a cluster, so these tests read a resolved
# case directly rather than asserting on rendered manifests.
# shellcheck disable=SC1091
. "${REPO_ROOT}/scripts/experiment"

# ── the interface resolves what the CSVs say ─────────────────────────────────

resolve_experiment_case kv-cache prompt-512-output-100 default
assert_eq "prompt-512-output-100" "${CASE_ID}" "resolve should load the requested case"
assert_eq "512" "${PROMPT_TOKEN_TARGET}" "resolve should load the case prompt target"
assert_eq "100" "${MAX_TOKENS}" "resolve should load the case output length"
assert_eq "default" "${PROFILE_ID}" "resolve should load the requested serving profile"
assert_eq "2048" "${MAX_MODEL_LEN}" "an all-blank profile row should inherit the shared default"
assert_eq "Qwen/Qwen2.5-0.5B-Instruct" "${MODEL}" "an all-blank profile row should inherit the shared model"

# Sparse profile rows override only the columns they fill.
resolve_experiment_case kv-cache prompt-512-output-100 long-context
assert_eq "long-context" "${PROFILE_ID}" "resolve should load the long-context profile"
assert_eq "9216" "${MAX_MODEL_LEN}" "a filled column should override the shared default"
assert_eq "Qwen/Qwen2.5-0.5B-Instruct" "${MODEL}" "a blank column should still inherit the shared default"

# ── the ordering hazard the old interface allowed ────────────────────────────
# load_client_policy is passed the case id that load_case sets. Called in the
# wrong order it does not fail: it silently resolves the default direct policy
# with a zero buffer, which is the wrong admission model rather than an error.
# Resolving must always produce the case's real policy.

CASE_ID=""
CLIENT_POLICY_ID=""
load_client_policy autoscaling "${CASE_ID}" >/dev/null 2>&1 || true
WRONG_ORDER_POLICY=${CLIENT_POLICY_ID}

resolve_experiment_case autoscaling burst-queued default
assert_eq "bounded-queue" "${CLIENT_POLICY_ID}" "resolve should load the case's real client policy"
assert_eq "queued" "${CLIENT_MODE}" "resolve should load the case's real admission mode"
assert_eq "240" "${CLIENT_BUFFER_CAPACITY_REQUESTS}" "resolve should load the case's real buffer capacity"
if [[ "${WRONG_ORDER_POLICY}" == "${CLIENT_POLICY_ID}" ]]; then
  fail "the ordering hazard should be real: sequencing loaders by hand should differ from resolving"
fi

# A serving profile carrying an extension resolves it, and a profile without one
# resolves blank rather than leaking the previous case's extension.
resolve_experiment_case kv-cache prompt-8192-output-300 long-context-fp8-kv
assert_eq "fp8" "${KV_CACHE_DTYPE}" "the fp8 profile should resolve its KV cache dtype"

resolve_experiment_case kv-cache prompt-512-output-100 default
assert_eq "" "${KV_CACHE_DTYPE}" "a profile with no extension should resolve a blank KV cache dtype"

# ── resolving is repeatable ──────────────────────────────────────────────────
# The same inputs must resolve to the same document every time, whatever ran
# before. This is what lets renderers resolve independently and still agree.
resolve_experiment_case fp4 steady-512-output-128 bf16-baseline
write_resolved_case fp4 "${TEST_TMPDIR}/a.json"
resolve_experiment_case kv-cache prompt-512-output-100 default
resolve_experiment_case fp4 steady-512-output-128 bf16-baseline
write_resolved_case fp4 "${TEST_TMPDIR}/b.json"
assert_eq "$(cat "${TEST_TMPDIR}/a.json")" "$(cat "${TEST_TMPDIR}/b.json")" \
  "resolving the same case twice should produce the same document"

# ── the document is the interface ────────────────────────────────────────────
FIELDS=$(experiment_case_fields | tr -d ' ' | sort)
for carried in CASE_ID PROFILE_ID MODEL VLLM_IMAGE MAX_MODEL_LEN CLIENT_POLICY_ID \
               COST_PROFILE_ID SERVING_DTYPE KV_CACHE_DTYPE; do
  assert_contains "${FIELDS}" "${carried}" "the resolved case should carry ${carried}"
done

# The document must satisfy its schema, and an unknown field must be refused.
resolve_experiment_case kv-cache prompt-512-output-100 default
write_resolved_case kv-cache "${TEST_TMPDIR}/resolved.json" || fail "write_resolved_case should succeed"
assert_file_exists "${TEST_TMPDIR}/resolved.json" "the resolved case should be written"

jq '.resolved.NOT_A_FIELD = "x"' "${TEST_TMPDIR}/resolved.json" > "${TEST_TMPDIR}/drifted.json"
if check_reports_against_schema "${EXPERIMENT_CASE_SCHEMA_VERSION}" "${TEST_TMPDIR}/drifted.json" >/dev/null 2>&1; then
  fail "an unknown resolved-case field should fail schema validation"
fi

# ── the CLI surface ──────────────────────────────────────────────────────────
run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" resolve \
  --experiment kv-cache --case prompt-512-output-100 --profile default
assert_status 0 "${COMMAND_STATUS}" "resolve should succeed for a valid case and profile"
assert_contains "${COMMAND_OUTPUT}" '"schema_version": "experiment-case/v1"' "resolve should emit a resolved case document"
assert_contains "${COMMAND_OUTPUT}" '"experiment": "kv-cache"' "resolve should name the experiment"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" resolve --experiment kv-cache
assert_status 1 "${COMMAND_STATUS}" "resolve should require a case"
assert_contains "${COMMAND_OUTPUT}" "resolve requires --case" "resolve should say which argument is missing"

run_and_capture /bin/bash "${REPO_ROOT}/scripts/experiment" resolve \
  --experiment kv-cache --case prompt-512-output-100 --profile no-such-profile
assert_status 1 "${COMMAND_STATUS}" "resolve should reject an unknown serving profile"

printf 'experiment_catalog_test.sh passed.\n'
