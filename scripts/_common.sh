#!/usr/bin/env bash

set -Eeuo pipefail

COMMON_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${COMMON_DIR}/lib/platform.sh"
