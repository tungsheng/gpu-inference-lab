#!/usr/bin/env bash

# Shared defaults and manifest paths for the dev environment scripts.
# shellcheck disable=SC2034
if [[ -z "${REPO_ROOT:-}" ]]; then
  DEV_ENVIRONMENT_PATHS_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  REPO_ROOT=$(cd -- "${DEV_ENVIRONMENT_PATHS_DIR}/.." && pwd)
fi

TF_DIR_DEFAULT="${REPO_ROOT}/infra/env/dev"
APP_NAMESPACE="${APP_NAMESPACE:-app}"
KARPENTER_NAMESPACE="${KARPENTER_NAMESPACE:-karpenter}"
KARPENTER_NODECLASS_NAME="${KARPENTER_NODECLASS_NAME:-gpu-serving}"
KARPENTER_NODEPOOL_NAME="${KARPENTER_NODEPOOL_NAME:-gpu-serving}"

AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_NAME="${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_NAME:-eks}"
AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_URL="${AWS_LOAD_BALANCER_CONTROLLER_HELM_REPO_URL:-https://aws.github.io/eks-charts}"
AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION="${AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION:-1.14.0}"
AWS_LOAD_BALANCER_CONTROLLER_WEBHOOK_SERVICE="${AWS_LOAD_BALANCER_CONTROLLER_WEBHOOK_SERVICE:-aws-load-balancer-webhook-service}"

KARPENTER_CHART_VERSION="${KARPENTER_CHART_VERSION:-1.9.0}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.0}"
METRICS_SERVER_MANIFEST_URL="https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

ALB_CONTROLLER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml"
NVIDIA_DEVICE_PLUGIN_MANIFEST_PATH="${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml"

TEST_APP_DEPLOYMENT_MANIFEST="${REPO_ROOT}/platform/test-app/deployment.yaml"
TEST_APP_SERVICE_MANIFEST="${REPO_ROOT}/platform/test-app/service.yaml"
TEST_APP_INGRESS_MANIFEST="${REPO_ROOT}/platform/test-app/ingress.yaml"

GPU_SMOKE_TEST_MANIFEST="${REPO_ROOT}/platform/tests/gpu-test.yaml"
GPU_INFERENCE_MANIFEST="${REPO_ROOT}/platform/inference/vllm-openai.yaml"
GPU_LOAD_TEST_MANIFEST="${REPO_ROOT}/platform/tests/gpu-load-test.yaml"

KARPENTER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/karpenter/serviceaccount.yaml"
KARPENTER_NODECLASS_MANIFEST="${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml"
KARPENTER_NODEPOOL_MANIFEST="${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml"
KARPENTER_CPU_SCALE_TEST_MANIFEST="${REPO_ROOT}/platform/tests/cpu-scale-test.yaml"
