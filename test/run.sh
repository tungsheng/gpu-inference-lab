#!/usr/bin/env bash

set -euo pipefail

TEST_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_COUNT=0

shopt -s nullglob

for test_file in "${TEST_DIR}"/*_test.sh; do
  TEST_COUNT=$((TEST_COUNT + 1))
  printf '==> %s\n' "$(basename "${test_file}")"
  "${test_file}"
done

printf 'All %d shell tests passed.\n' "${TEST_COUNT}"
