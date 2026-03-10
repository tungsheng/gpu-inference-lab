#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
TF_DIR=${1:-"${REPO_ROOT}/infra/env/dev"}

require_command() {
  local command_name=$1

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

require_command aws
require_command helm
require_command kubectl
require_command terraform

if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform directory not found: ${TF_DIR}" >&2
  exit 1
fi

current_step="reading Terraform outputs"

wait_for_webhook_endpoints() {
  local namespace=$1
  local service_name=$2
  local timeout_seconds=${3:-300}
  local start_time

  start_time=$(date +%s)

  while true; do
    local endpoint_addresses
    endpoint_addresses=$(kubectl get endpointslice \
      -n "${namespace}" \
      -l "kubernetes.io/service-name=${service_name}" \
      -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || true)

    if [[ -n "${endpoint_addresses}" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      echo "Timed out waiting for EndpointSlice addresses on service ${service_name} in namespace ${namespace}" >&2
      kubectl get pods -n "${namespace}" >&2 || true
      kubectl get endpointslice -n "${namespace}" -l "kubernetes.io/service-name=${service_name}" >&2 || true
      return 1
    fi

    sleep 5
  done
}

retry_command() {
  local attempts=$1
  local delay_seconds=$2
  shift 2

  local attempt=1

  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi

    echo "Command failed on attempt ${attempt}/${attempts}; retrying in ${delay_seconds}s: $*" >&2
    attempt=$((attempt + 1))
    sleep "${delay_seconds}"
  done
}

print_diagnostics() {
  echo "Collecting Kubernetes diagnostics..." >&2
  kubectl config current-context >&2 || true
  kubectl get nodes -o wide >&2 || true
  kubectl get pods -n kube-system -o wide >&2 || true
  kubectl get deployment aws-load-balancer-controller -n kube-system -o wide >&2 || true
  kubectl describe deployment aws-load-balancer-controller -n kube-system >&2 || true
  kubectl get svc aws-load-balancer-webhook-service -n kube-system -o wide >&2 || true
  kubectl get endpointslice -n kube-system -l kubernetes.io/service-name=aws-load-balancer-webhook-service -o yaml >&2 || true
  kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=200 >&2 || true
  kubectl get service -n app >&2 || true
  kubectl get ingress -n app >&2 || true
  kubectl get events -n kube-system --sort-by=.metadata.creationTimestamp >&2 || true
}

handle_error() {
  local exit_code=$1
  local line_number=$2

  trap - ERR
  echo "post-terraform-apply failed at line ${line_number} during step: ${current_step}" >&2
  print_diagnostics
  exit "${exit_code}"
}

trap 'handle_error $? $LINENO' ERR

cluster_name=$(terraform -chdir="${TF_DIR}" output -raw cluster_name)
aws_region=$(terraform -chdir="${TF_DIR}" output -raw aws_region)
vpc_id=$(terraform -chdir="${TF_DIR}" output -raw vpc_id)
aws_load_balancer_controller_role_arn=$(terraform -chdir="${TF_DIR}" output -raw aws_load_balancer_controller_role_arn)

current_step="updating kubeconfig"
aws eks update-kubeconfig --name "${cluster_name}" --region "${aws_region}"

current_step="verifying cluster connectivity"
kubectl cluster-info

current_step="applying AWS load balancer controller service account"
kubectl apply -f "${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml"
current_step="annotating AWS load balancer controller service account"
kubectl annotate serviceaccount \
  -n kube-system \
  aws-load-balancer-controller \
  "eks.amazonaws.com/role-arn=${aws_load_balancer_controller_role_arn}" \
  --overwrite

current_step="updating Helm repositories"
helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update

current_step="installing AWS load balancer controller"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --wait \
  --timeout 10m \
  --set clusterName="${cluster_name}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${aws_region}" \
  --set vpcId="${vpc_id}"

current_step="waiting for AWS load balancer controller rollout"
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=10m
current_step="waiting for AWS load balancer webhook endpoints"
wait_for_webhook_endpoints kube-system aws-load-balancer-webhook-service 300

current_step="ensuring app namespace exists"
if ! kubectl get namespace app >/dev/null 2>&1; then
  kubectl create namespace app
fi

current_step="applying test app deployment"
kubectl apply -f "${REPO_ROOT}/platform/test-app/deployment.yaml"
current_step="applying test app service"
retry_command 5 5 kubectl apply -f "${REPO_ROOT}/platform/test-app/service.yaml"
current_step="applying test app ingress"
retry_command 5 5 kubectl apply -f "${REPO_ROOT}/platform/test-app/ingress.yaml"
