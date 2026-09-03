#!/usr/bin/env bash
# shellcheck disable=SC2034

# The report contract shared by every script that writes a report artifact.
#
# Four report families are produced by this repository, and all four are
# machine-checked against a schema under schemas/. A report that does not match
# its schema is a defect in the producer, not an acceptable variation: the
# curated evidence and the published conclusions are read back out of these
# documents.
#
# Adding a field to a renderer means adding it to that family's schema in the
# same change; the schemas are closed, so an unexpected field fails validation.

REPORTS_LIB_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPORTS_REPO_ROOT=$(cd -- "${REPORTS_LIB_DIR}/../.." && pwd)

REPORT_SCHEMA_DIR="${REPORT_SCHEMA_DIR:-${REPORTS_REPO_ROOT}/schemas}"
REPORT_SCHEMA_VALIDATOR="${REPORTS_LIB_DIR}/validate_report.py"

EXPERIMENT_REPORT_SCHEMA_VERSION="experiment-report/v1"
EVALUATE_REPORT_SCHEMA_VERSION="evaluate-report/v1"
FAILURE_DRILL_REPORT_SCHEMA_VERSION="failure-drill-report/v1"
KV_CACHE_TRACE_SCHEMA_VERSION="kv-cache-trace/v1"

report_generated_at() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

json_escape() {
  local value=${1:-}

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "${value}"
}

# Map a schema_version ("evaluate-report/v1") to its schema file.
report_schema_path() {
  local family=$1

  case "${family}" in
    */v[0-9]*) ;;
    *)
      printf 'Not a schema version: %s\n' "${family}" >&2
      return 1
      ;;
  esac

  printf '%s/%s.%s.json\n' "${REPORT_SCHEMA_DIR}" "${family%%/*}" "${family##*/}"
}

# Check one or more report files against the schema for a family.
check_reports_against_schema() {
  local family=$1
  shift
  local schema_path

  schema_path=$(report_schema_path "${family}") || return 1

  if [[ ! -f "${schema_path}" ]]; then
    printf 'Missing report schema: %s\n' "${schema_path}" >&2
    return 1
  fi

  if [[ ! -f "${REPORT_SCHEMA_VALIDATOR}" ]]; then
    printf 'Missing report schema validator: %s\n' "${REPORT_SCHEMA_VALIDATOR}" >&2
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required to check reports against %s\n' "${schema_path##*/}" >&2
    return 1
  fi

  python3 "${REPORT_SCHEMA_VALIDATOR}" --schema "${schema_path}" "$@"
}
