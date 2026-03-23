#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-paths.sh"
TF_DIR="${TF_DIR_DEFAULT}"

if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform directory not found: ${TF_DIR}" >&2
  exit 1
fi

for arg in "$@"; do
  if [[ "${arg}" == "-destroy" ]]; then
    echo "scripts/apply-dev.sh does not support terraform apply -destroy. Use ./scripts/destroy-dev.sh or terraform -chdir=${TF_DIR} destroy directly." >&2
    exit 1
  fi

  if [[ "${arg}" == "-target" || "${arg}" == -target=* ]]; then
    echo "scripts/apply-dev.sh only supports full environment apply. Use terraform -chdir=${TF_DIR} apply directly for targeted operations." >&2
    exit 1
  fi

  if [[ "${arg}" == "-refresh-only" || "${arg}" == -refresh-only=* ]]; then
    echo "scripts/apply-dev.sh only supports full environment apply. Use terraform -chdir=${TF_DIR} apply directly for refresh-only operations." >&2
    exit 1
  fi
done

terraform -chdir="${TF_DIR}" apply "$@"
"${SCRIPT_DIR}/post-terraform-apply.sh" "${TF_DIR}"
