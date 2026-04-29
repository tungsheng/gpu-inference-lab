#!/usr/bin/env bash

# Shared report contract metadata for scripts/evaluate.
# shellcheck disable=SC2034
EVALUATE_REPORT_SCHEMA_VERSION="evaluate-report/v1"

evaluate_report_generated_at() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}
