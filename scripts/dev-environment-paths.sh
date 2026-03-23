#!/usr/bin/env bash

# shellcheck disable=SC2034
: "${REPO_ROOT:?REPO_ROOT must be set before sourcing scripts/dev-environment-paths.sh}"

TF_DIR_DEFAULT="${REPO_ROOT}/infra/env/dev"

ALB_CONTROLLER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml"
NVIDIA_DEVICE_PLUGIN_MANIFEST_PATH="${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml"

TEST_APP_DEPLOYMENT_MANIFEST="${REPO_ROOT}/platform/test-app/deployment.yaml"
TEST_APP_SERVICE_MANIFEST="${REPO_ROOT}/platform/test-app/service.yaml"
TEST_APP_INGRESS_MANIFEST="${REPO_ROOT}/platform/test-app/ingress.yaml"

GPU_SMOKE_TEST_MANIFEST="${REPO_ROOT}/platform/tests/gpu-test.yaml"
GPU_INFERENCE_MANIFEST="${REPO_ROOT}/platform/inference/gpu-inference.yaml"

KARPENTER_SERVICE_ACCOUNT_MANIFEST="${REPO_ROOT}/platform/karpenter/serviceaccount.yaml"
KARPENTER_NODECLASS_MANIFEST="${REPO_ROOT}/platform/karpenter/nodeclass-default.yaml"
KARPENTER_NODEPOOL_MANIFEST="${REPO_ROOT}/platform/karpenter/nodepool-default.yaml"
KARPENTER_CPU_SCALE_TEST_MANIFEST="${REPO_ROOT}/platform/tests/cpu-scale-test.yaml"
