#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-paths.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/dev-environment-common.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/kube.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/terraform.sh"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/diagnostics.sh"
# shellcheck disable=SC2034
SCRIPT_NAME="destroy-dev"
TF_DIR="${TF_DIR_DEFAULT}"
SKIP_K8S_CLEANUP=${SKIP_K8S_CLEANUP:-0}

current_step="validating prerequisites"

usage() {
  cat <<EOF
Usage:
  ./scripts/destroy-dev.sh [terraform destroy args]

Examples:
  ./scripts/destroy-dev.sh
  ./scripts/destroy-dev.sh -auto-approve
  SKIP_K8S_CLEANUP=1 ./scripts/destroy-dev.sh

Notes:
  - This wrapper tears down Kubernetes resources before destroying Terraform infrastructure.
  - For targeted destroys, use terraform directly.
EOF
}

require_command terraform

require_directory "${TF_DIR}" "Terraform directory"

reject_unsupported_destroy_args() {
  local arg

  for arg in "$@"; do
    case "${arg}" in
      -target|-target=*)
        log_error "scripts/destroy-dev.sh only supports full environment teardown. Use terraform -chdir=${TF_DIR} destroy directly for targeted destroys."
        exit 1
        ;;
    esac
  done
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

reject_unsupported_destroy_args "$@"

delete_aws_load_balancer_controller_crds() {
  kubectl delete crd \
    targetgroupbindings.elbv2.k8s.aws \
    ingressclassparams.elbv2.k8s.aws \
    --ignore-not-found=true
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
      log_error "timed out waiting for ALB ${dns_name} deletion in ${aws_region}"
      aws elbv2 describe-load-balancers \
        --region "${aws_region}" \
        --query "LoadBalancers[?DNSName=='${dns_name}']" \
        --output json >&2 || true
      return 1
    fi

    sleep 10
  done
}

delete_test_app() {
  local ingress_hostname=$1
  local aws_region=$2

  run_step "deleting test app ingress" kubectl delete -f "${TEST_APP_INGRESS_MANIFEST}" --ignore-not-found=true
  run_step "waiting for test app ingress deletion" wait_for_resource_deletion ingress "${TEST_APP_INGRESS_NAME}" "${APP_NAMESPACE}" 600

  if [[ -n "${ingress_hostname}" ]]; then
    run_step "waiting for ALB deletion" wait_for_alb_deletion "${ingress_hostname}" "${aws_region}" 900
  fi

  run_step "deleting test app service" kubectl delete -f "${TEST_APP_SERVICE_MANIFEST}" --ignore-not-found=true
  run_step "deleting test app deployment" kubectl delete -f "${TEST_APP_DEPLOYMENT_MANIFEST}" --ignore-not-found=true
}

delete_gpu_workloads() {
  run_step "deleting GPU smoke test pod" kubectl delete -f "${GPU_SMOKE_TEST_MANIFEST}" --ignore-not-found=true
  run_step "deleting GPU load test job" kubectl delete -f "${GPU_LOAD_TEST_MANIFEST}" --ignore-not-found=true
  run_step "deleting GPU inference deployment" kubectl delete -f "${GPU_INFERENCE_MANIFEST}" --ignore-not-found=true
}

delete_karpenter_stack() {
  if crd_exists "nodepools.karpenter.sh"; then
    run_step "deleting Karpenter CPU scale test pod" kubectl delete -f "${KARPENTER_CPU_SCALE_TEST_MANIFEST}" --ignore-not-found=true
    run_step "deleting Karpenter NodePool" kubectl delete -f "${KARPENTER_NODEPOOL_MANIFEST}" --ignore-not-found=true
    run_step "waiting for Karpenter NodePool deletion" wait_for_resource_deletion nodepool "${KARPENTER_NODEPOOL_NAME}" "" 300
  fi

  if crd_exists "nodeclaims.karpenter.sh"; then
    run_step "waiting for Karpenter NodeClaims deletion" wait_for_no_resources nodeclaims "" "" 600
  fi

  run_step "waiting for Karpenter-managed nodes to terminate" wait_for_no_resources nodes "" "karpenter.sh/nodepool" 600

  if crd_exists "ec2nodeclasses.karpenter.k8s.aws"; then
    run_step "deleting Karpenter EC2NodeClass" kubectl delete -f "${KARPENTER_NODECLASS_MANIFEST}" --ignore-not-found=true
    run_step "waiting for Karpenter EC2NodeClass deletion" wait_for_resource_deletion ec2nodeclass "${KARPENTER_NODECLASS_NAME}" "" 300
  fi

  if helm status "${KARPENTER_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" >/dev/null 2>&1; then
    run_step "uninstalling Karpenter Helm release" helm uninstall "${KARPENTER_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" --wait
  fi

  if helm status "${KARPENTER_CRD_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" >/dev/null 2>&1; then
    run_step "uninstalling Karpenter CRD Helm release" helm uninstall "${KARPENTER_CRD_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" --wait
  fi

  run_step "deleting Karpenter service account and namespace" delete_karpenter_namespace
}

delete_karpenter_namespace() {
  kubectl delete -f "${KARPENTER_SERVICE_ACCOUNT_MANIFEST}" --ignore-not-found=true
  wait_for_resource_deletion namespace "${KARPENTER_NAMESPACE}" "" 300
}

delete_nvidia_device_plugin() {
  kubectl delete -f "${NVIDIA_DEVICE_PLUGIN_MANIFEST_PATH}" --ignore-not-found=true
  wait_for_resource_deletion daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" kube-system 300
}

delete_metrics_server() {
  if resource_exists deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" kube-system \
    || resource_exists apiservice v1beta1.metrics.k8s.io \
    || resource_exists serviceaccount metrics-server kube-system; then
    run_step "deleting metrics server" kubectl delete -f "${METRICS_SERVER_MANIFEST_URL}" --ignore-not-found=true
    run_step "waiting for metrics server deployment deletion" wait_for_resource_deletion deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" kube-system 300
    run_step "waiting for metrics API deletion" wait_for_resource_deletion apiservice v1beta1.metrics.k8s.io "" 300
  fi
}

delete_app_namespace() {
  kubectl delete namespace "${APP_NAMESPACE}" --ignore-not-found=true
  wait_for_resource_deletion namespace "${APP_NAMESPACE}" "" 300
}

wait_for_aws_load_balancer_controller_cleanup() {
  if api_resource_exists "targetgroupbindings.elbv2.k8s.aws"; then
    run_step "waiting for AWS load balancer controller custom resources to disappear" \
      wait_for_no_resources targetgroupbindings "" "" 300 1
  fi

  if api_resource_exists "ingressclassparams.elbv2.k8s.aws"; then
    run_step "waiting for AWS load balancer controller ingress class params to disappear" \
      wait_for_no_resources ingressclassparams "" "" 300
  fi
}

delete_aws_load_balancer_controller() {
  if helm status "${AWS_LOAD_BALANCER_CONTROLLER_RELEASE_NAME}" -n kube-system >/dev/null 2>&1; then
    run_step "uninstalling AWS load balancer controller" helm uninstall "${AWS_LOAD_BALANCER_CONTROLLER_RELEASE_NAME}" -n kube-system --wait
  fi

  run_step "deleting AWS load balancer controller service account" \
    kubectl delete -f "${ALB_CONTROLLER_SERVICE_ACCOUNT_MANIFEST}" --ignore-not-found=true

  wait_for_aws_load_balancer_controller_cleanup

  if crd_exists "targetgroupbindings.elbv2.k8s.aws" || crd_exists "ingressclassparams.elbv2.k8s.aws"; then
    run_step "deleting AWS load balancer controller CRDs" delete_aws_load_balancer_controller_crds
    run_step "waiting for AWS load balancer controller target group binding CRD deletion" \
      wait_for_resource_deletion crd targetgroupbindings.elbv2.k8s.aws "" 300
    run_step "waiting for AWS load balancer controller ingress class params CRD deletion" \
      wait_for_resource_deletion crd ingressclassparams.elbv2.k8s.aws "" 300
  fi
}

print_diagnostics() {
  print_destroy_diagnostics
}

handle_error() {
  local exit_code=$1
  local line_number=$2

  trap - ERR
  log_error "failed at line ${line_number} during step: ${current_step}"

  if [[ "${SKIP_K8S_CLEANUP}" != "1" ]]; then
    print_diagnostics
  fi

  exit "${exit_code}"
}

trap 'handle_error $? $LINENO' ERR

current_step="reading Terraform outputs"
cluster_name=$(terraform_output_optional "${TF_DIR}" cluster_name)
aws_region=$(terraform_output_optional "${TF_DIR}" aws_region)

if [[ "${SKIP_K8S_CLEANUP}" == "1" ]]; then
  log_warn "skipping Kubernetes cleanup because SKIP_K8S_CLEANUP=1"
elif [[ -n "${cluster_name}" && -n "${aws_region}" ]]; then
  run_step "validating Kubernetes cleanup prerequisites" require_commands aws helm kubectl
  run_step "updating kubeconfig" aws eks update-kubeconfig --name "${cluster_name}" --region "${aws_region}"
  run_step "verifying cluster connectivity" verify_cluster_connectivity

  ingress_hostname=$(kubectl get ingress "${TEST_APP_INGRESS_NAME}" -n "${APP_NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  delete_test_app "${ingress_hostname}" "${aws_region}"
  delete_gpu_workloads
  delete_karpenter_stack
  run_step "deleting NVIDIA device plugin" delete_nvidia_device_plugin
  delete_metrics_server
  run_step "deleting app namespace" delete_app_namespace
  delete_aws_load_balancer_controller
else
  log_error "Terraform outputs for cluster name/region are unavailable; refusing to skip Kubernetes cleanup implicitly. Re-run with SKIP_K8S_CLEANUP=1 if the cluster is already gone and cleanup is intentionally impossible."
  exit 1
fi

run_step "destroying Terraform-managed infrastructure" terraform -chdir="${TF_DIR}" destroy "$@"
log_success "environment destroy complete"
