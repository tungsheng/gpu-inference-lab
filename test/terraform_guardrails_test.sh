#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

EKS_MODULE_FILE="${REPO_ROOT}/infra/modules/eks/main.tf"
MODULE_CONTENT=$(cat "${EKS_MODULE_FILE}")

assert_contains "${MODULE_CONTENT}" 'eks_managed_node_groups = {' "EKS module should still declare managed node groups"
assert_contains "${MODULE_CONTENT}" 'system = {' "EKS module should keep the managed system node group"
assert_contains "${MODULE_CONTENT}" 'workload                  = "system"' "managed node groups should remain system-only"
assert_not_contains "${MODULE_CONTENT}" 'gpu = {' "EKS module should not reintroduce a managed GPU node group"
assert_not_contains "${MODULE_CONTENT}" 'gpu-serving = {' "EKS module should not define a managed gpu-serving node group"
