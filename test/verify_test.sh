#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\"" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml')" \
"    : > \"${TEST_TMPDIR}/deployment-present\"" \
"    exit 0" \
"    ;;" \
"  'get nodes -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name')" \
"    if [[ -f \"${TEST_TMPDIR}/deployment-present\" ]]; then" \
"      printf '%s\n' 'node/gpu-serving-1'" \
"    fi" \
"    exit 0" \
"    ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true')" \
"    rm -f \"${TEST_TMPDIR}/deployment-present\"" \
"    exit 0" \
"    ;;" \
"  *) printf 'unexpected kubectl command: %s\n' \"\$*\" >&2; exit 1 ;;" \
"esac"

write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' \"\$*\" >> \"${TEST_TMPDIR}/curl.log\"" \
"printf '200'"

run_and_capture env PATH="${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash "${REPO_ROOT}/scripts/verify"

assert_status 0 "${COMMAND_STATUS}" "scripts/verify should complete the minimal cold-start flow"
assert_contains "${COMMAND_OUTPUT}" "OK 6/6 delete deployment and wait for zero gpu nodes" "verify should clean up the deployment and GPU node count"
assert_contains "${COMMAND_OUTPUT}" "First successful response:" "verify should summarize the first successful response timing"
assert_contains "${COMMAND_OUTPUT}" "Public inference URL: http://public-edge.example.com/v1/completions" "verify should print the public inference URL it exercised"

KUBECTL_LOG=$(cat "${TEST_TMPDIR}/kubectl.log")
assert_contains "${KUBECTL_LOG}" "apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml" "verify should apply the deployment-only inference manifest"
assert_contains "${KUBECTL_LOG}" "delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true" "verify should delete the deployment manifest when the check completes"
