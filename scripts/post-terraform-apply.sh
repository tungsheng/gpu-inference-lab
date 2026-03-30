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
SCRIPT_NAME="post-terraform-apply"
TF_DIR=${1:-"${TF_DIR_DEFAULT}"}

current_step="reading Terraform outputs"

require_commands aws helm kubectl terraform
require_directory "${TF_DIR}" "Terraform directory"

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
      log_error "timed out waiting for EndpointSlice addresses on service ${service_name} in namespace ${namespace}"
      kubectl get pods -n "${namespace}" >&2 || true
      kubectl get endpointslice -n "${namespace}" -l "kubernetes.io/service-name=${service_name}" >&2 || true
      return 1
    fi

    sleep 5
  done
}

apply_aws_load_balancer_controller_crds() {
  local crd_manifest
  crd_manifest=$(mktemp)

  if ! helm show crds "${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_NAME}/aws-load-balancer-controller" \
    --version "${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION}" > "${crd_manifest}"; then
    rm -f "${crd_manifest}"
    return 1
  fi

  if [[ ! -s "${crd_manifest}" ]]; then
    rm -f "${crd_manifest}"
    log_error "failed to render AWS Load Balancer Controller CRDs for chart ${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION}"
    return 1
  fi

  if ! kubectl apply -f "${crd_manifest}"; then
    rm -f "${crd_manifest}"
    return 1
  fi

  wait_for_crd "targetgroupbindings.elbv2.k8s.aws" 180
  wait_for_crd "ingressclassparams.elbv2.k8s.aws" 180

  rm -f "${crd_manifest}"
}

print_diagnostics() {
  print_apply_diagnostics
}

handle_error() {
  local exit_code=$1
  local line_number=$2

  trap - ERR
  log_error "failed at line ${line_number} during step: ${current_step}"
  print_diagnostics
  exit "${exit_code}"
}

trap 'handle_error $? $LINENO' ERR

wait_for_metrics_api() {
  local timeout_seconds=${1:-300}
  local start_time

  start_time=$(date +%s)

  while true; do
    local available_status
    available_status=$(kubectl get apiservice v1beta1.metrics.k8s.io \
      -o jsonpath="{.status.conditions[?(@.type=='Available')].status}" 2>/dev/null || true)

    if [[ "${available_status}" == "True" ]]; then
      return 0
    fi

    if (( $(date +%s) - start_time >= timeout_seconds )); then
      log_error "timed out waiting for the metrics API to become available"
      kubectl get apiservice v1beta1.metrics.k8s.io -o yaml >&2 || true
      kubectl get deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" -n kube-system -o yaml >&2 || true
      return 1
    fi

    sleep 5
  done
}

install_metrics_server() {
  run_step "applying metrics server manifest" \
    retry_command 5 5 kubectl apply -f "${METRICS_SERVER_MANIFEST_URL}"

  run_step "waiting for metrics-server deployment to appear" \
    wait_for_resource_existence deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" kube-system 60

  run_step "patching metrics-server deployment args" \
    retry_command 5 5 \
      kubectl patch deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" \
        -n kube-system \
        --type strategic \
        -p '{
          "spec": {
            "template": {
              "spec": {
                "containers": [
                  {
                    "name": "metrics-server",
                    "args": [
                      "--cert-dir=/tmp",
                      "--secure-port=10250",
                      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
                      "--kubelet-use-node-status-port",
                      "--metric-resolution=15s",
                      "--kubelet-insecure-tls"
                    ]
                  }
                ]
              }
            }
          }
        }'

  run_step "waiting for metrics-server rollout" \
    kubectl rollout status "deployment/${METRICS_SERVER_DEPLOYMENT_NAME}" -n kube-system --timeout=5m
  run_step "waiting for metrics API" wait_for_metrics_api 300
}

install_aws_load_balancer_controller() {
  run_step "applying AWS load balancer controller service account" \
    kubectl apply -f "${ALB_CONTROLLER_SERVICE_ACCOUNT_MANIFEST}"

  run_step "annotating AWS load balancer controller service account" \
    kubectl annotate serviceaccount \
      -n kube-system \
      "${AWS_LOAD_BALANCER_CONTROLLER_SERVICE_ACCOUNT_NAME}" \
      "eks.amazonaws.com/role-arn=${aws_load_balancer_controller_role_arn}" \
      --overwrite

  run_step "adding AWS Helm repository" \
    helm repo add "${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_NAME}" "${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_URL}" --force-update

  run_step "updating Helm repository metadata" helm repo update
  run_step "applying AWS load balancer controller CRDs" apply_aws_load_balancer_controller_crds

  run_step "installing AWS load balancer controller" \
    helm upgrade --install "${AWS_LOAD_BALANCER_CONTROLLER_RELEASE_NAME}" \
      "${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_NAME}/aws-load-balancer-controller" \
      -n kube-system \
      --wait \
      --timeout 10m \
      --version "${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION}" \
      --set clusterName="${cluster_name}" \
      --set serviceAccount.create=false \
      --set serviceAccount.name="${AWS_LOAD_BALANCER_CONTROLLER_SERVICE_ACCOUNT_NAME}" \
      --set region="${aws_region}" \
      --set vpcId="${vpc_id}"

  run_step "waiting for AWS load balancer controller rollout" \
    kubectl rollout status "deployment/${AWS_LOAD_BALANCER_CONTROLLER_RELEASE_NAME}" -n kube-system --timeout=10m

  run_step "waiting for AWS load balancer webhook endpoints" \
    wait_for_webhook_endpoints kube-system "${AWS_LOAD_BALANCER_CONTROLLER_WEBHOOK_SERVICE}" 300
}

install_karpenter() {
  run_step "applying Karpenter service account" \
    retry_command 5 5 kubectl apply -f "${KARPENTER_SERVICE_ACCOUNT_MANIFEST}"

  helm registry logout public.ecr.aws >/dev/null 2>&1 || true

  run_step "installing Karpenter CRD chart" \
    retry_command 3 10 \
      helm upgrade --install "${KARPENTER_CRD_RELEASE_NAME}" oci://public.ecr.aws/karpenter/karpenter-crd \
        -n "${KARPENTER_NAMESPACE}" \
        --create-namespace \
        --version "${KARPENTER_CHART_VERSION}" \
        --wait \
        --timeout 10m

  run_step "waiting for Karpenter CRDs to establish" wait_for_crd "nodepools.karpenter.sh" 180
  run_step "waiting for Karpenter NodeClaim CRD to establish" wait_for_crd "nodeclaims.karpenter.sh" 180
  run_step "waiting for Karpenter EC2NodeClass CRD to establish" wait_for_crd "ec2nodeclasses.karpenter.k8s.aws" 180

  run_step "installing Karpenter controller chart" \
    retry_command 3 10 \
      helm upgrade --install "${KARPENTER_RELEASE_NAME}" oci://public.ecr.aws/karpenter/karpenter \
        -n "${KARPENTER_NAMESPACE}" \
        --create-namespace \
        --version "${KARPENTER_CHART_VERSION}" \
        --wait \
        --timeout 10m \
        --set settings.clusterName="${cluster_name}" \
        --set serviceAccount.create=false \
        --set serviceAccount.name="${KARPENTER_SERVICE_ACCOUNT_NAME}"

  run_step "waiting for Karpenter rollout" \
    kubectl rollout status "deployment/${KARPENTER_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" --timeout=10m

  run_step "applying Karpenter EC2NodeClass" \
    retry_command 5 5 kubectl apply -f "${KARPENTER_NODECLASS_MANIFEST}"
  run_step "waiting for Karpenter EC2NodeClass readiness" \
    wait_for_status_condition ec2nodeclass "${KARPENTER_NODECLASS_NAME}" Ready True 300
  run_step "applying Karpenter NodePool" \
    retry_command 5 5 kubectl apply -f "${KARPENTER_NODEPOOL_MANIFEST}"
  run_step "waiting for Karpenter NodePool readiness" \
    wait_for_status_condition nodepool "${KARPENTER_NODEPOOL_NAME}" Ready True 300
}

install_test_app() {
  run_step "applying test app deployment" kubectl apply -f "${TEST_APP_DEPLOYMENT_MANIFEST}"
  run_step "applying test app service" retry_command 5 5 kubectl apply -f "${TEST_APP_SERVICE_MANIFEST}"
  run_step "applying test app ingress" retry_command 5 5 kubectl apply -f "${TEST_APP_INGRESS_MANIFEST}"
}

cluster_name=$(terraform_output_required "${TF_DIR}" cluster_name)
aws_region=$(terraform_output_required "${TF_DIR}" aws_region)
vpc_id=$(terraform_output_required "${TF_DIR}" vpc_id)
aws_load_balancer_controller_role_arn=$(terraform_output_required "${TF_DIR}" aws_load_balancer_controller_role_arn)

run_step "updating kubeconfig" aws eks update-kubeconfig --name "${cluster_name}" --region "${aws_region}"
run_step "verifying cluster connectivity" kubectl cluster-info

install_aws_load_balancer_controller
run_step "installing metrics server" install_metrics_server
run_step "installing Karpenter" install_karpenter
run_step "installing NVIDIA device plugin" retry_command 5 5 kubectl apply -f "${NVIDIA_DEVICE_PLUGIN_MANIFEST_PATH}"
run_step "waiting for NVIDIA device plugin rollout" kubectl rollout status "daemonset/${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" -n kube-system --timeout=10m
run_step "ensuring app namespace exists" ensure_namespace "${APP_NAMESPACE}"
install_test_app
