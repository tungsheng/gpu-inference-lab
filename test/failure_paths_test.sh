#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/helpers/test-helpers.sh"

TEST_PATH_SUFFIX="/usr/bin:/bin:/usr/sbin:/sbin"

write_common_up_stubs() {
  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$2\" in" \
"  init|apply) exit 0 ;;" \
"  output)" \
"    case \"\$4\" in" \
"      cluster_name) printf '%s\n' 'gpu-inference' ;;" \
"      aws_region) printf '%s\n' 'us-west-2' ;;" \
"      vpc_id) printf '%s\n' 'vpc-12345' ;;" \
"      aws_load_balancer_controller_role_arn) printf '%s\n' 'arn:aws:iam::123456789012:role/alb-controller' ;;" \
"      *) exit 1 ;;" \
"    esac" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'repo add') exit 0 ;;" \
"  'repo update') exit 0 ;;" \
"  'show crds')" \
"    printf '%s\n' 'apiVersion: apiextensions.k8s.io/v1'" \
"    printf '%s\n' 'kind: CustomResourceDefinition'" \
"    exit 0" \
"    ;;" \
"  'upgrade --install') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"
}

write_common_verify_stubs() {
  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"
}

write_common_down_stubs() {
  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$2\" in" \
"  init|destroy) exit 0 ;;" \
"  output)" \
"    case \"\$4\" in" \
"      cluster_name) printf '%s\n' 'gpu-inference' ;;" \
"      aws_region) printf '%s\n' 'us-west-2' ;;" \
"      vpc_id) printf '%s\n' 'vpc-12345' ;;" \
"      aws_load_balancer_controller_role_arn) printf '%s\n' 'arn:aws:iam::123456789012:role/alb-controller' ;;" \
"      *) exit 1 ;;" \
"    esac" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1\" in" \
"  uninstall) exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"
}

run_missing_prereq_test() {
  setup_test_tmpdir
  link_system_command dirname
  run_and_capture env PATH="${TEST_BIN}" /bin/bash "${REPO_ROOT}/scripts/up"
  assert_status 1 "${COMMAND_STATUS}" "up should fail fast when required tools are missing"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 1/7 checking prerequisites" "up should fail in the prerequisite stage when tools are missing"
  assert_contains "${COMMAND_OUTPUT}" "Missing required command(s): aws helm kubectl terraform" "up should explain which commands are missing"
  teardown_test_tmpdir
}

run_up_ingress_timeout_test() {
  setup_test_tmpdir
  write_common_up_stubs

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml') exit 0 ;;" \
"  'annotate serviceaccount -n kube-system aws-load-balancer-controller eks.amazonaws.com/role-arn=arn:aws:iam::123456789012:role/alb-controller --overwrite') exit 0 ;;" \
"  apply\ -f\ /tmp/*|apply\ -f\ */tmp.*) exit 0 ;;" \
"  'rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=10m') exit 0 ;;" \
"  'get endpoints aws-load-balancer-webhook-service -n kube-system -o jsonpath={.subsets[*].addresses[*].ip}') printf '%s\n' '10.0.0.1' ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml') exit 0 ;;" \
"  'wait --for=condition=Established crd/nodepools.karpenter.sh --timeout=10m') exit 0 ;;" \
"  'wait --for=condition=Established crd/nodeclaims.karpenter.sh --timeout=10m') exit 0 ;;" \
"  'wait --for=condition=Established crd/ec2nodeclasses.karpenter.k8s.aws --timeout=10m') exit 0 ;;" \
"  'rollout status deployment/karpenter -n karpenter --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready ec2nodeclass/gpu-serving --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving.yaml') exit 0 ;;" \
"  'wait --for=condition=Ready nodepool/gpu-serving --timeout=10m') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml') exit 0 ;;" \
"  'rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=10m') exit 0 ;;" \
"  'get namespace app') exit 1 ;;" \
"  'create namespace app') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;" \
"  'apply -f ${REPO_ROOT}/platform/inference/ingress.yaml') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    INGRESS_HOSTNAME_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/up"

  assert_status 1 "${COMMAND_STATUS}" "up should fail when the ingress hostname never appears"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 7/7 apply public inference edge" "up should fail on the inference edge stage when the hostname never appears"
  teardown_test_tmpdir
}

run_verify_gpu_timeout_test() {
  setup_test_tmpdir
  write_common_verify_stubs

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool=gpu-serving -o name') exit 0 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_READY_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when no GPU node ever appears"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 3/6 wait for first gpu node" "verify should fail on the GPU node stage when provisioning never starts"
  teardown_test_tmpdir
}

run_verify_ready_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool=gpu-serving -o name') printf '%s\n' 'node/gpu-serving-1' ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when the deployment never becomes ready"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 4/6 wait for ready deployment" "verify should fail on the rollout stage when readiness never completes"
  teardown_test_tmpdir
}

run_verify_response_timeout_test() {
  setup_test_tmpdir

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'apply -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml') exit 0 ;;" \
"  'get nodes -l karpenter.sh/nodepool=gpu-serving -o name') printf '%s\n' 'node/gpu-serving-1' ;;" \
"  'rollout status deployment/vllm-openai -n app --timeout=20m') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  *) exit 0 ;;" \
"esac"

  write_stub curl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '503'"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_RESPONSE_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/verify"

  assert_status 1 "${COMMAND_STATUS}" "verify should fail when the public endpoint never returns 200"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 5/6 wait for first successful response" "verify should fail on the public response stage when curl never succeeds"
  teardown_test_tmpdir
}

run_down_alb_timeout_test() {
  setup_test_tmpdir
  write_common_down_stubs

  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  'elbv2 describe-load-balancers') printf '%s\n' '1' ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'cluster-info') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/ingress.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get ingress vllm-openai-ingress -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/service.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get service vllm-openai -n app') exit 1 ;;" \
"  'delete -f ${REPO_ROOT}/platform/inference/vllm-openai.yaml --ignore-not-found=true') exit 0 ;;" \
"  'get deployment vllm-openai -n app') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  run_and_capture env \
    PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" \
    VERIFY_CLEANUP_TIMEOUT_SECONDS=1 \
    POLL_INTERVAL_SECONDS=0 \
    /bin/bash "${REPO_ROOT}/scripts/down"

  assert_status 1 "${COMMAND_STATUS}" "down should fail when the ALB never disappears after ingress deletion"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 4/7 remove inference edge" "down should fail on inference edge teardown when ALB deletion stalls"
  teardown_test_tmpdir
}

run_down_cluster_unreachable_test() {
  setup_test_tmpdir
  write_common_down_stubs

  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"

  write_stub kubectl \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"case \"\$*\" in" \
"  'cluster-info') exit 1 ;;" \
"  *) exit 0 ;;" \
"esac"

  run_and_capture env PATH="${TEST_BIN}:${TEST_PATH_SUFFIX}" /bin/bash "${REPO_ROOT}/scripts/down" -auto-approve

  assert_status 1 "${COMMAND_STATUS}" "down should stop before terraform destroy when the cluster cannot be reached"
  assert_contains "${COMMAND_OUTPUT}" "FAIL 3/7 connect cluster context" "down should fail in the cluster connection stage when the cluster is unreachable"
  assert_contains "${COMMAND_OUTPUT}" "terraform -chdir=${REPO_ROOT}/infra/env/dev destroy -auto-approve" "down should print the exact manual fallback destroy command"
  teardown_test_tmpdir
}

run_missing_prereq_test
run_up_ingress_timeout_test
run_verify_gpu_timeout_test
run_verify_ready_timeout_test
run_verify_response_timeout_test
run_down_alb_timeout_test
run_down_cluster_unreachable_test
