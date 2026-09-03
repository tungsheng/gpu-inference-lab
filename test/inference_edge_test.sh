#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

setup_test_tmpdir
trap teardown_test_tmpdir EXIT

render_with() {
  local destination="${TEST_TMPDIR}/ingress.yaml"

  rm -f "${destination}"
  run_and_capture env "$@" /bin/bash -c '
    . "'"${REPO_ROOT}"'/scripts/_common.sh"
    render_inference_ingress_manifest "'"${destination}"'"
  '
  RENDERED_MANIFEST=""
  if [[ -f "${destination}" ]]; then
    RENDERED_MANIFEST=$(cat "${destination}")
  fi
}

# An explicit source range renders straight through.
render_with GPU_INFERENCE_INBOUND_CIDRS="198.51.100.7/32"
assert_status 0 "${COMMAND_STATUS}" "an explicit CIDR should render successfully"
assert_contains "${RENDERED_MANIFEST}" 'alb.ingress.kubernetes.io/inbound-cidrs: "198.51.100.7/32"' "the rendered ingress should carry the requested source range"
assert_contains "${RENDERED_MANIFEST}" 'alb.ingress.kubernetes.io/scheme: internet-facing' "the rendered ingress should default to the internet-facing scheme"
assert_not_contains "${RENDERED_MANIFEST}" '@' "the rendered ingress should have no unsubstituted placeholders"

# A bare address is normalized to a single-host range.
render_with GPU_INFERENCE_INBOUND_CIDRS="198.51.100.7"
assert_status 0 "${COMMAND_STATUS}" "a bare IPv4 address should be accepted"
assert_contains "${RENDERED_MANIFEST}" '"198.51.100.7/32"' "a bare IPv4 address should be normalized to /32"

# Multiple ranges are preserved as a comma-separated list.
render_with GPU_INFERENCE_INBOUND_CIDRS="198.51.100.0/24, 203.0.113.7"
assert_status 0 "${COMMAND_STATUS}" "a list of source ranges should be accepted"
assert_contains "${RENDERED_MANIFEST}" '"198.51.100.0/24,203.0.113.7/32"' "a list should render as comma-separated CIDRs"

# An internal scheme is allowed for private-edge runs.
render_with GPU_INFERENCE_INBOUND_CIDRS="10.0.0.0/8" GPU_INFERENCE_INGRESS_SCHEME="internal"
assert_status 0 "${COMMAND_STATUS}" "the internal scheme should be accepted"
assert_contains "${RENDERED_MANIFEST}" 'alb.ingress.kubernetes.io/scheme: internal' "the internal scheme should reach the rendered ingress"

# Opening the edge to the internet stays possible but is called out loudly.
render_with GPU_INFERENCE_INBOUND_CIDRS="0.0.0.0/0"
assert_status 0 "${COMMAND_STATUS}" "an explicit 0.0.0.0/0 should still be allowed"
assert_contains "${COMMAND_OUTPUT}" "WARNING: the inference edge accepts traffic from 0.0.0.0/0." "an unrestricted edge should warn about the exposure"
assert_contains "${COMMAND_OUTPUT}" "unauthenticated OpenAI-compatible API over plain HTTP" "the warning should say what is exposed"

# Malformed input fails closed rather than rendering a permissive listener.
for invalid in "not-an-ip" "198.51.100.7/33" "198.51.100.999/32" "198.51.100/24" ""; do
  render_with GPU_INFERENCE_INBOUND_CIDRS="${invalid}"
  assert_status 1 "${COMMAND_STATUS}" "invalid source range '${invalid}' should fail"
  assert_file_not_exists "${TEST_TMPDIR}/ingress.yaml" "invalid source range '${invalid}' should not render a manifest"
done

render_with GPU_INFERENCE_INBOUND_CIDRS="198.51.100.7/32" GPU_INFERENCE_INGRESS_SCHEME="public"
assert_status 1 "${COMMAND_STATUS}" "an unknown scheme should fail"
assert_contains "${COMMAND_OUTPUT}" "Invalid GPU_INFERENCE_INGRESS_SCHEME: public" "an unknown scheme should name the offending value"

# "auto" resolves this machine public IP through the lookup service.
write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\n' '203.0.113.42'"
render_with PATH="${TEST_BIN}:${PATH}" GPU_INFERENCE_INBOUND_CIDRS="auto"
assert_status 0 "${COMMAND_STATUS}" "auto should resolve through the public IP lookup"
assert_contains "${RENDERED_MANIFEST}" '"203.0.113.42/32"' "auto should restrict the edge to the detected public IP"

# A failed lookup must not silently fall back to an open edge.
write_stub curl \
"#!/usr/bin/env bash" \
"exit 1"
render_with PATH="${TEST_BIN}:${PATH}" GPU_INFERENCE_INBOUND_CIDRS="auto"
assert_status 1 "${COMMAND_STATUS}" "a failed public IP lookup should fail the render"
assert_contains "${COMMAND_OUTPUT}" "Unable to detect this machine public IP" "a failed lookup should explain what went wrong"
assert_contains "${COMMAND_OUTPUT}" "Set GPU_INFERENCE_INBOUND_CIDRS to an explicit source range" "a failed lookup should suggest the manual override"

printf 'inference_edge_test.sh passed.\n'
