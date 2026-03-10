#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
TF_DIR="${REPO_ROOT}/infra/env/dev"

for arg in "$@"; do
  if [[ "${arg}" == "-destroy" ]]; then
    echo "scripts/apply-dev.sh does not support terraform apply -destroy. Use ./scripts/destroy-dev.sh or terraform -chdir=${TF_DIR} destroy directly." >&2
    exit 1
  fi
done

terraform -chdir="${TF_DIR}" apply "$@"
"${SCRIPT_DIR}/post-terraform-apply.sh" "${TF_DIR}"
