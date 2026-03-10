#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
TF_DIR="${REPO_ROOT}/infra/env/dev"
SKIP_K8S_CLEANUP=${SKIP_K8S_CLEANUP:-0}

require_command() {
  local command_name=$1

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

log() {
  echo "[destroy-dev] $*"
}

current_step="validating prerequisites"

require_command terraform

if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform directory not found: ${TF_DIR}" >&2
  exit 1
fi

for arg in "$@"; do
  if [[ "${arg}" == "-target" || "${arg}" == -target=* ]]; then
    echo "scripts/destroy-dev.sh only supports full environment teardown. Use terraform -chdir=${TF_DIR} destroy directly for targeted destroys." >&2
    exit 1
  fi
done

terraform_outputs_json=$(terraform -chdir="${TF_DIR}" output -json 2>/dev/null || printf '{}')

has_terraform_output() {
  local output_name=$1

  grep -q "\"${output_name}\":" <<<"${terraform_outputs_json}"
}

terraform_output() {
  local output_name=$1

  if ! has_terraform_output "${output_name}"; then
    return 1
  fi

  terraform -chdir="${TF_DIR}" output -raw "${output_name}" 2>/dev/null
}

wait_for_resource_deletion() {
  local resource_kind=$1
  local resource_name=$2
  local resource_namespace=${3:-}
  local timeout_seconds=${4:-300}
  local start_time

  start_time=$(date +%s)

  while true; do
    if [[ -n "${resource_namespace}" ]]; then
      if ! kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" >/dev/null 2>&1; then
        return 0
      fi
    else
      if ! kubectl get "${resource_kind}" "${resource_name}" >/dev/null 2>&1; then
        return 0
      fi
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      echo "Timed out waiting for ${resource_kind}/${resource_name} deletion" >&2
      if [[ -n "${resource_namespace}" ]]; then
        kubectl get "${resource_kind}" "${resource_name}" -n "${resource_namespace}" -o yaml >&2 || true
      else
        kubectl get "${resource_kind}" "${resource_name}" -o yaml >&2 || true
      fi
      return 1
    fi

    sleep 5
  done
}

wait_for_alb_deletion() {
  local dns_name=$1
  local aws_region=$2
  local timeout_seconds=${3:-900}
  local start_time

  if [[ -z "${dns_name}" ]]; then
    return 0
  fi

  start_time=$(date +%s)

  while true; do
    local alb_count
    alb_count=$(aws elbv2 describe-load-balancers \
      --region "${aws_region}" \
      --query "length(LoadBalancers[?DNSName=='${dns_name}'])" \
      --output text)

    if [[ "${alb_count}" == "0" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      echo "Timed out waiting for ALB ${dns_name} deletion in ${aws_region}" >&2
      aws elbv2 describe-load-balancers \
        --region "${aws_region}" \
        --query "LoadBalancers[?DNSName=='${dns_name}']" \
        --output json >&2 || true
      return 1
    fi

    sleep 10
  done
}

print_diagnostics() {
  echo "Collecting teardown diagnostics..." >&2
  kubectl config current-context >&2 || true
  kubectl get ingress -A >&2 || true
  kubectl get service -A >&2 || true
  kubectl get pods -n kube-system -o wide >&2 || true
  kubectl get targetgroupbinding -A >&2 || true
  helm list -n kube-system >&2 || true
}

handle_error() {
  local exit_code=$1
  local line_number=$2

  trap - ERR
  echo "destroy-dev failed at line ${line_number} during step: ${current_step}" >&2

  if [[ "${SKIP_K8S_CLEANUP}" != "1" ]]; then
    print_diagnostics
  fi

  exit "${exit_code}"
}

trap 'handle_error $? $LINENO' ERR

current_step="reading Terraform outputs"
cluster_name=$(terraform_output cluster_name || true)
aws_region=$(terraform_output aws_region || true)

if [[ "${SKIP_K8S_CLEANUP}" == "1" ]]; then
  log "Skipping Kubernetes cleanup because SKIP_K8S_CLEANUP=1"
elif [[ -n "${cluster_name}" && -n "${aws_region}" ]]; then
  current_step="validating Kubernetes cleanup prerequisites"
  require_command aws
  require_command helm
  require_command kubectl

  current_step="updating kubeconfig"
  aws eks update-kubeconfig --name "${cluster_name}" --region "${aws_region}"

  current_step="verifying cluster connectivity"
  kubectl cluster-info >/dev/null

  ingress_hostname=$(kubectl get ingress echo-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  current_step="deleting test app ingress"
  kubectl delete -f "${REPO_ROOT}/platform/test-app/ingress.yaml" --ignore-not-found=true

  current_step="waiting for test app ingress deletion"
  wait_for_resource_deletion ingress echo-ingress app 600

  if [[ -n "${ingress_hostname}" ]]; then
    current_step="waiting for ALB deletion"
    wait_for_alb_deletion "${ingress_hostname}" "${aws_region}" 900
  fi

  current_step="deleting test app service"
  kubectl delete -f "${REPO_ROOT}/platform/test-app/service.yaml" --ignore-not-found=true

  current_step="deleting test app deployment"
  kubectl delete -f "${REPO_ROOT}/platform/test-app/deployment.yaml" --ignore-not-found=true

  current_step="deleting app namespace"
  kubectl delete namespace app --ignore-not-found=true
  wait_for_resource_deletion namespace app "" 300

  if helm status aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
    current_step="uninstalling AWS load balancer controller"
    helm uninstall aws-load-balancer-controller -n kube-system --wait
  fi

  current_step="deleting AWS load balancer controller service account"
  kubectl delete -f "${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml" --ignore-not-found=true
else
  log "Terraform outputs for cluster name/region are unavailable; skipping Kubernetes cleanup"
fi

current_step="destroying Terraform-managed infrastructure"
terraform -chdir="${TF_DIR}" destroy "$@"
