#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# The contract is a library, so the tests call it directly rather than through a
# CLI with a process fake.
in_contract() {
  run_and_capture /bin/bash -c '
    . "'"${REPO_ROOT}"'/scripts/_common.sh"
    '"$1"'
  '
}

# Every family this repository writes must resolve to a schema on disk.
for family in \
  "${EXPERIMENT_REPORT_SCHEMA_VERSION:-experiment-report/v1}" \
  "${EVALUATE_REPORT_SCHEMA_VERSION:-evaluate-report/v1}" \
  "${FAILURE_DRILL_REPORT_SCHEMA_VERSION:-failure-drill-report/v1}" \
  "${KV_CACHE_TRACE_SCHEMA_VERSION:-kv-cache-trace/v1}"; do
  in_contract "report_schema_path '${family}'"
  assert_status 0 "${COMMAND_STATUS}" "report_schema_path should resolve ${family}"
  assert_file_exists "${COMMAND_OUTPUT}" "${family} should have a schema on disk"
done

# A version string that is not a family must be rejected, not turned into a path.
in_contract "report_schema_path 'not-a-family'"
assert_status 1 "${COMMAND_STATUS}" "report_schema_path should reject a non-version argument"

# Every schema version named in the scripts must be one the contract declares.
DECLARED=$(grep -ohE '"[a-z-]+/v[0-9]+"' "${REPO_ROOT}/scripts/lib/reports.sh" | tr -d '"' | sort -u)
USED=$(grep -rhoE '"[a-z-]+-(report|trace)/v[0-9]+"' \
  "${REPO_ROOT}/scripts/evaluate" "${REPO_ROOT}/scripts/experiment" \
  "${REPO_ROOT}/scripts/failure" "${REPO_ROOT}/observatory/kv-cache/kv_observe.py" \
  2>/dev/null | tr -d '"' | sort -u || true)
for version in ${USED}; do
  assert_contains "${DECLARED}" "${version}" "schema version ${version} should be declared in scripts/lib/reports.sh"
done

# json_escape is shared precisely because a weaker copy had drifted: the drill
# runner's version escaped only backslash and quote.
# shellcheck disable=SC2016
in_contract 'json_escape "$(printf "a\nb\tc\"d\\\\e")"'
assert_eq '"a\nb\tc\"d\\e"' "${COMMAND_OUTPUT}" "json_escape should escape newline, tab, quote and backslash"

# shellcheck disable=SC2016
in_contract 'json_escape "$(printf "x\ry")"'
assert_eq '"x\ry"' "${COMMAND_OUTPUT}" "json_escape should escape carriage return"

# The escaped result must be parseable as JSON, which is the point of escaping.
ESCAPED=$(/bin/bash -c '. "'"${REPO_ROOT}"'/scripts/_common.sh"; json_escape "$(printf "line\nbreak\ttab")"')
printf '{"value": %s}\n' "${ESCAPED}" > "${TEST_TMPDIR}/escaped.json"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${TEST_TMPDIR}/escaped.json" \
  || fail "json_escape output should parse as JSON"

# The curated evidence corpus is checked through the same interface the scripts use.
in_contract "check_reports_against_schema '${EXPERIMENT_REPORT_SCHEMA_VERSION:-experiment-report/v1}' \"${REPO_ROOT}\"/experiments/*/evidence/*.json"
assert_status 0 "${COMMAND_STATUS}" "curated evidence should match the experiment report schema"

# An unknown field must fail: the schemas are closed so renderer drift is caught.
jq '.results.serving.tokens_per_watt = 3' \
  "${REPO_ROOT}/experiments/kv-cache/evidence/experiment-kv-cache-prompt-512-output-100-default-20260501-160128.json" \
  > "${TEST_TMPDIR}/drifted.json"
in_contract "check_reports_against_schema '${EXPERIMENT_REPORT_SCHEMA_VERSION:-experiment-report/v1}' '${TEST_TMPDIR}/drifted.json'"
assert_status 1 "${COMMAND_STATUS}" "an unexpected field should fail schema validation"
assert_contains "${COMMAND_OUTPUT}" "unexpected field 'tokens_per_watt'" "the failure should name the drifted field"

# Reports written before later fields were added to the renderer are still
# evaluate-report/v1 documents. The schema was first derived from current runs
# only, which made it reject 18 of 23 real historical reports; these fixtures
# are scrubbed copies of the older shapes, kept so that cannot regress.
for fixture in "${REPO_ROOT}"/test/fixtures/evaluate-reports/*.json; do
  in_contract "check_reports_against_schema '${EVALUATE_REPORT_SCHEMA_VERSION:-evaluate-report/v1}' '${fixture}'"
  assert_status 0 "${COMMAND_STATUS}" "historical report $(basename "${fixture}") should satisfy the evaluate schema"
done

# Those fixtures are committed, so they must carry no cluster addresses.
FIXTURE_BLOB=$(cat "${REPO_ROOT}"/test/fixtures/evaluate-reports/*.json)
assert_not_contains "${FIXTURE_BLOB}" "public_endpoint" "committed report fixtures should have operational endpoints scrubbed"
assert_not_contains "${FIXTURE_BLOB}" "amazonaws.com" "committed report fixtures should not carry cluster hostnames"

# evaluate-report/v1 covers three document shapes; each must validate, and a
# document matching none of them must report the closest shape.
printf '{"schema_version":"evaluate-report/v1","generated_at":"x"}\n' > "${TEST_TMPDIR}/bogus.json"
in_contract "check_reports_against_schema '${EVALUATE_REPORT_SCHEMA_VERSION:-evaluate-report/v1}' '${TEST_TMPDIR}/bogus.json'"
assert_status 1 "${COMMAND_STATUS}" "a document matching no evaluate shape should fail"
assert_contains "${COMMAND_OUTPUT}" "matched none of 3 allowed shapes" "the failure should say how many shapes were tried"
assert_contains "${COMMAND_OUTPUT}" "closest is" "the failure should name the closest shape"

printf 'report_contract_test.sh passed.\n'
