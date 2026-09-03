#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

# The readout is reachable without a cluster, so these tests call it directly
# instead of driving an eleven-stage run through a process fake.
# shellcheck disable=SC1091
. "${REPO_ROOT}/scripts/evaluate"

# ── cost model ───────────────────────────────────────────────────────────────
# Previously untested end to end: every stubbed run asserted a null cost.

assert_eq "0.526" "$(gpu_instance_hourly_cost g4dn.xlarge on-demand)" "g4dn.xlarge on-demand hourly cost"
assert_eq "0.316" "$(gpu_instance_hourly_cost g4dn.xlarge spot)" "g4dn.xlarge spot should price below on-demand"
assert_eq "" "$(gpu_instance_hourly_cost m7i-flex.large on-demand)" "a non-GPU instance type should have no GPU price"
assert_eq "" "$(gpu_instance_hourly_cost "" on-demand)" "an unknown instance type should have no price"

# An hour costs the hourly rate; half an hour costs half; nothing costs nothing.
assert_eq "0.526000" "$(multiply_decimal_by_seconds_over_hour 0.526 3600)" "one hour should cost the hourly rate"
assert_eq "0.263000" "$(multiply_decimal_by_seconds_over_hour 0.526 1800)" "half an hour should cost half the hourly rate"
assert_eq "0.000000" "$(multiply_decimal_by_seconds_over_hour 0.526 0)" "zero seconds should cost nothing"
assert_eq "" "$(multiply_decimal_by_seconds_over_hour "" 3600)" "an absent rate should produce no cost"

assert_eq "1.052000" "$(sum_decimal_values 0.526 0.526)" "sum_decimal_values should add two rates"
assert_eq "0.263000" "$(divide_decimal_values 0.526 2)" "divide_decimal_values should halve a rate"
assert_eq "" "$(divide_decimal_values 0.526 0)" "dividing by zero should yield no value rather than an error"
assert_eq "37.500" "$(subtract_decimal_from_hundred 62.5)" "subtract_decimal_from_hundred should give remaining headroom"

# ── capacity verdict ─────────────────────────────────────────────────────────
# capacity_assessment_status <target> <queue_wait> <ttft> <waiting> <avg_gpu> <max_gpu>
# These thresholds decide the capacity readout the project publishes, so pin them.

assert_eq "unknown" "$(capacity_assessment_status 8 "" 0.2 1 40 60)" "a missing metric should read as unknown, not balanced"
assert_eq "unknown" "$(capacity_assessment_status 8 0.1 0.2 1 40 "")" "a missing GPU maximum should read as unknown"

assert_eq "saturated" "$(capacity_assessment_status 8 0.1 0.2 1 40 96)" "a GPU above 95 percent should read as saturated"
assert_eq "saturated" "$(capacity_assessment_status 8 1.5 0.2 1 40 60)" "queue wait above one second should read as saturated"
assert_eq "saturated" "$(capacity_assessment_status 8 0.1 1.5 1 40 60)" "TTFT above one second should read as saturated"
assert_eq "saturated" "$(capacity_assessment_status 8 0.1 0.2 9 40 60)" "more waiting requests than the target should read as saturated"

assert_eq "underutilized" "$(capacity_assessment_status 8 0.1 0.2 1 40 60)" "an idle GPU with a short queue should read as underutilized"
assert_eq "underutilized" "$(capacity_assessment_status "" 0.1 0.2 1 40 60)" "an idle GPU with no target should still read as underutilized"

assert_eq "balanced" "$(capacity_assessment_status 8 0.1 0.2 1 70 90)" "a busy GPU inside its budgets should read as balanced"
assert_eq "balanced" "$(capacity_assessment_status 8 0.5 0.2 1 40 60)" "an idle GPU with a growing queue should not read as underutilized"

# The reason must explain the verdict, not restate it.
UNKNOWN_REASON=$(capacity_assessment_reason 8 "" 0.2 1 40 60)
assert_contains "${UNKNOWN_REASON}" "unavailable" "an unknown verdict should say a metric was unavailable"

# ── sweep scoring ────────────────────────────────────────────────────────────
# sweep_target_score <target> <latency> <queue_wait> <ttft> <waiting> <per_gpu>
#                    <avg_gpu> <max_gpu> <burst_cost>
# Lower is better: determine_sweep_recommendation keeps the smaller score.

FAST=$(sweep_target_score 4 1.0 0.05 0.10 0 8 70 80 0.10)
SLOW=$(sweep_target_score 4 9.0 2.00 1.50 20 8 70 80 0.10)
[[ -n "${FAST}" ]] || fail "a scored target should produce a value"
decimal_less_than "${FAST}" "${SLOW}" \
  || fail "a fast target should score below a slow one (lower is better)"

CHEAP=$(sweep_target_score 4 1.0 0.05 0.10 0 8 70 80 0.10)
DEAR=$(sweep_target_score 4 1.0 0.05 0.10 0 8 70 80 5.00)
decimal_less_than "${CHEAP}" "${DEAR}" \
  || fail "a cheaper burst should score below a more expensive identical one"

# Status priority orders the recommendation before score is consulted.
BALANCED_PRIORITY=$(sweep_target_status_priority balanced)
UNDER_PRIORITY=$(sweep_target_status_priority underutilized)
SATURATED_PRIORITY=$(sweep_target_status_priority saturated)
(( BALANCED_PRIORITY > SATURATED_PRIORITY )) || fail "balanced should outrank saturated"
(( UNDER_PRIORITY > SATURATED_PRIORITY )) || fail "underutilized should outrank saturated"

# ── time arithmetic ──────────────────────────────────────────────────────────
assert_eq "60" "$(seconds_between 1000 1060)" "seconds_between should subtract epochs"
assert_eq "" "$(seconds_between "" 1060)" "seconds_between should yield nothing when an endpoint is missing"
assert_eq "" "$(seconds_between 1000 "")" "seconds_between should yield nothing without an end epoch"

# ── formatting ───────────────────────────────────────────────────────────────
assert_eq "null" "$(json_nullable_number "")" "an absent number should render as JSON null"
assert_eq "1.5" "$(json_nullable_number 1.5)" "a present number should render bare"
assert_eq "null" "$(json_nullable_string "")" "an absent string should render as JSON null"
assert_eq '"x"' "$(json_nullable_string x)" "a present string should render quoted"
assert_eq "n/a" "$(display_metric "")" "an absent metric should display as n/a"

# ── the seam itself ──────────────────────────────────────────────────────────
# Every field the readout reads must travel in the record, or rendering from a
# record would silently differ from rendering straight after a run.
FIELDS=$(evaluate_measurement_fields | tr -d ' ' | sort)
for carried in AVG_GPU_UTILIZATION_PERCENT EVALUATION_START_TIME FIRST_GPU_CAPACITY_TYPE \
               P95_REQUEST_LATENCY_SECONDS PEAK_WAITING_REQUESTS METRICS_COLLECTION_STATUS; do
  assert_contains "${FIELDS}" "${carried}" "the record should carry ${carried}"
done

# Derived values must NOT travel: they are recomputed, not replayed.
for derived in ESTIMATED_BURST_COST CAPACITY_ASSESSMENT AVG_GPU_HEADROOM_PERCENT \
               PEAK_ACTIVE_REQUESTS_PER_GPU_NODE; do
  assert_not_contains "${FIELDS}" "${derived}" "${derived} is derived and must not travel in the record"
done

# A record round-trips through its schema.
EVALUATION_PROFILE="zero-idle"
CURRENT_POLICY="active-pressure"
AVG_GPU_UTILIZATION_PERCENT="62.5"
FIRST_GPU_CAPACITY_TYPE="spot"
write_measurement_record "${TEST_TMPDIR}/record.json" || fail "write_measurement_record should succeed"
assert_file_exists "${TEST_TMPDIR}/record.json" "the record should be written"

AVG_GPU_UTILIZATION_PERCENT=""
FIRST_GPU_CAPACITY_TYPE=""
CURRENT_POLICY=""
load_measurement_record "${TEST_TMPDIR}/record.json" || fail "load_measurement_record should succeed"
assert_eq "62.5" "${AVG_GPU_UTILIZATION_PERCENT}" "GPU utilization should survive the round trip"
assert_eq "spot" "${FIRST_GPU_CAPACITY_TYPE}" "capacity type should survive the round trip"
assert_eq "active-pressure" "${CURRENT_POLICY}" "policy should survive the round trip"

# A record that does not match its schema is refused rather than partially loaded.
printf '{"schema_version":"evaluate-measurement/v1","generated_at":"x","measurements":{}}\n' \
  > "${TEST_TMPDIR}/bad-record.json"
if load_measurement_record "${TEST_TMPDIR}/bad-record.json" >/dev/null 2>&1; then
  fail "a record missing its measurements should be refused"
fi

printf 'evaluation_readout_test.sh passed.\n'
