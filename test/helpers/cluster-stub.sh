#!/usr/bin/env bash
# shellcheck disable=SC2034

# Composable stubs for the CLI tools the lifecycle scripts drive.
#
# 88 of the 116 distinct kubectl command strings in this suite appeared in more
# than one file, written out in full each time, which made stub definition the
# bulk of the suite. Tests now compose named bundles and add only the arms whose
# response actually matters to what they assert.
#
# The catch-all stays strict. An unexpected command still fails the stub, so a
# script that starts issuing a new command is noticed rather than tolerated.

KUBECTL_STUB_PRELUDE=()
KUBECTL_STUB_ARMS=()

kubectl_stub_reset() {
  KUBECTL_STUB_PRELUDE=()
  KUBECTL_STUB_ARMS=()
}

# Raw lines placed before the case statement, for stubs that need state.
kubectl_prelude() {
  KUBECTL_STUB_PRELUDE+=("$@")
}

# kubectl_arm <case pattern> <body>
# Arms are matched in the order they are added, so a test can shadow a bundle
# arm by adding its own before calling the bundle.
kubectl_arm() {
  KUBECTL_STUB_ARMS+=("  $1) $2 ;;")
}

# kubectl_absent <resource...> -- "kubectl get <resource>" reports not found,
# which is how the teardown waiters see a deleted object.
kubectl_absent() {
  local resource
  for resource in "$@"; do
    kubectl_arm "'get ${resource}'" "exit 1"
  done
}

# kubectl_deletes_manifest <repo-relative path...> -- accept the delete.
kubectl_deletes_manifest() {
  local path
  for path in "$@"; do
    kubectl_arm "'delete -f ${REPO_ROOT}/${path} --ignore-not-found=true'" "exit 0"
  done
}

kubectl_ok() {
  local command
  for command in "$@"; do
    kubectl_arm "'${command}'" "exit 0"
  done
}

kubectl_prints() {  # <command> <output>
  KUBECTL_STUB_ARMS+=("  '$1') printf '%s\\n' '$2' ;;")
}

# ── bundles ──────────────────────────────────────────────────────────────────

# The monitoring namespace disappears once it has been deleted.
kubectl_bundle_monitoring_namespace() {
  kubectl_prelude \
"if [[ \"\$*\" == 'delete namespace monitoring --ignore-not-found=true' ]]; then" \
"  : > \"${TEST_TMPDIR}/monitoring-deleted\"" \
"  exit 0" \
"fi" \
"if [[ \"\$*\" == 'get namespace monitoring' ]]; then" \
"  if [[ -f \"${TEST_TMPDIR}/monitoring-deleted\" ]]; then" \
"    exit 1" \
"  fi" \
"  exit 0" \
"fi"
}

kubectl_bundle_inference_teardown() {
  kubectl_deletes_manifest \
    platform/workloads/validation/gpu-load-test.yaml \
    platform/workloads/validation/gpu-warm-placeholder.yaml \
    platform/inference/hpa.yaml \
    platform/inference/service.yaml \
    platform/inference/vllm-openai.yaml
  kubectl_ok 'delete ingress vllm-openai-ingress -n app --ignore-not-found=true'
  kubectl_absent \
    'job gpu-load-test -n app' \
    'deployment gpu-warm-placeholder -n app' \
    'hpa vllm-openai -n app' \
    'ingress vllm-openai-ingress -n app' \
    'service vllm-openai -n app' \
    'deployment vllm-openai -n app'
}

kubectl_bundle_karpenter_teardown() {
  kubectl_ok \
    'get crd nodepools.karpenter.sh' \
    'get crd ec2nodeclasses.karpenter.k8s.aws' \
    'get crd nodeclaims.karpenter.sh' \
    'delete nodepool/gpu-serving --ignore-not-found=true' \
    'get nodeclaims -l karpenter.sh/nodepool in (gpu-serving-ondemand,gpu-serving-spot) -o name' \
    'get nodes -l workload=gpu -o name'
  kubectl_deletes_manifest \
    platform/legacy/karpenter/nodepool-gpu-warm.yaml \
    platform/karpenter/nodepool-gpu-serving-spot.yaml \
    platform/karpenter/nodepool-gpu-serving-ondemand.yaml \
    platform/karpenter/nodeclass-gpu-serving.yaml
  kubectl_absent \
    'nodepool gpu-warm-1' \
    'nodepool gpu-serving-spot' \
    'nodepool gpu-serving-ondemand' \
    'nodepool gpu-serving' \
    'ec2nodeclass gpu-serving'
}

kubectl_bundle_observability_teardown() {
  kubectl_deletes_manifest \
    platform/observability/dashboards/experiment-dashboard.yaml \
    platform/observability/dashboards/capacity-dashboard.yaml \
    platform/observability/dashboards/serving-dashboard.yaml \
    platform/observability/pushgateway.yaml
  kubectl_ok \
    'delete daemonset dcgm-exporter -n monitoring --ignore-not-found=true' \
    'delete service dcgm-exporter -n monitoring --ignore-not-found=true' \
    'get crd servicemonitors.monitoring.coreos.com' \
    'delete servicemonitor dcgm-exporter -n monitoring --ignore-not-found=true' \
    'get crd podmonitors.monitoring.coreos.com' \
    'delete podmonitor karpenter-metrics -n monitoring --ignore-not-found=true' \
    'delete podmonitor vllm-metrics -n monitoring --ignore-not-found=true'
  kubectl_absent 'apiservice v1beta1.custom.metrics.k8s.io'
}

kubectl_bundle_system_teardown() {
  kubectl_deletes_manifest \
    platform/karpenter/serviceaccount.yaml \
    platform/system/nvidia-device-plugin.yaml
  kubectl_absent 'daemonset nvidia-device-plugin-daemonset -n kube-system'
}

# Everything ./scripts/down drives, in one call.
kubectl_bundle_down_happy_path() {
  kubectl_ok 'cluster-info'
  kubectl_prints 'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}' 'public-edge.example.com'
  kubectl_bundle_monitoring_namespace
  kubectl_bundle_inference_teardown
  kubectl_bundle_karpenter_teardown
  kubectl_bundle_observability_teardown
  kubectl_bundle_system_teardown
}

# Everything ./scripts/up drives on the happy path. Shared with the bring-up
# failure tests, which shadow individual arms to fail at one stage.
kubectl_bundle_up_happy_path() {
  KUBECTL_STUB_ARMS+=(
    "  'cluster-info') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/controller/aws-load-balancer-controller/service-account.yaml') exit 0 ;;"
    "  'annotate serviceaccount -n kube-system aws-load-balancer-controller eks.amazonaws.com/role-arn=arn:aws:iam::123456789012:role/alb-controller --overwrite') exit 0 ;;"
    "  apply\ -f\ /tmp/*|apply\ -f\ */tmp.*) exit 0 ;;"
    "  'rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=10m') exit 0 ;;"
    "  'get endpointslice -n kube-system -l kubernetes.io/service-name=aws-load-balancer-webhook-service -o jsonpath={.items[*].endpoints[*].addresses[*]}') printf '%s\n' '10.0.0.1' ;;"
    "  'rollout status deployment/kube-prometheus-stack-operator -n monitoring --timeout=10m') exit 0 ;;"
    "  'rollout status deployment/kube-prometheus-stack-grafana -n monitoring --timeout=10m') exit 0 ;;"
    "  'rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring --timeout=10m') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/vllm-podmonitor.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/karpenter-podmonitor.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/pushgateway.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/dcgm-exporter.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/dashboards/serving-dashboard.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/dashboards/capacity-dashboard.yaml') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/observability/dashboards/experiment-dashboard.yaml') exit 0 ;;"
    "  'get deployment pushgateway -n monitoring') exit 0 ;;"
    "  'rollout status deployment/pushgateway -n monitoring --timeout=5m') exit 0 ;;"
    "  'get daemonset dcgm-exporter -n monitoring') exit 0 ;;"
    "  'rollout status deployment/prometheus-adapter -n monitoring --timeout=10m') exit 0 ;;"
    "  'get apiservice v1beta1.custom.metrics.k8s.io -o jsonpath={.status.conditions[?(@.type=='\"'\"'Available'\"'\"')].status}') printf '%s\n' 'True' ;;"
    "  'apply -f ${REPO_ROOT}/platform/karpenter/serviceaccount.yaml') exit 0 ;;"
    "  'wait --for=condition=Established crd/nodepools.karpenter.sh --timeout=10m') exit 0 ;;"
    "  'wait --for=condition=Established crd/nodeclaims.karpenter.sh --timeout=10m') exit 0 ;;"
    "  'wait --for=condition=Established crd/ec2nodeclasses.karpenter.k8s.aws --timeout=10m') exit 0 ;;"
    "  'rollout status deployment/karpenter -n karpenter --timeout=10m') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/karpenter/nodeclass-gpu-serving.yaml') exit 0 ;;"
    "  'wait --for=condition=Ready ec2nodeclass/gpu-serving --timeout=10m') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-ondemand.yaml') exit 0 ;;"
    "  'wait --for=condition=Ready nodepool/gpu-serving-ondemand --timeout=10m') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/karpenter/nodepool-gpu-serving-spot.yaml') exit 0 ;;"
    "  'wait --for=condition=Ready nodepool/gpu-serving-spot --timeout=10m') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/system/nvidia-device-plugin.yaml') exit 0 ;;"
    "  'rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=10m') exit 0 ;;"
    "  'get namespace app') exit 1 ;;"
    "  'create namespace app') exit 0 ;;"
    "  'apply -f ${REPO_ROOT}/platform/inference/service.yaml') exit 0 ;;"
    "  'apply -f '*'/gpu-lab-ingress.'*) exit 0 ;;"
    "  'get ingress vllm-openai-ingress -n app -o jsonpath={.status.loadBalancer.ingress[0].hostname}') printf '%s\n' 'public-edge.example.com' ;;"
    "  'get nodes -l workload=gpu -o name') exit 0 ;;"
  )
}
# kubectl_stub_write [catch-all body]
kubectl_stub_write() {
  local catch_all=${1:-"printf 'unexpected kubectl command: %s\\n' \"\$*\" >&2; exit 1"}
  local lines=(
    "#!/usr/bin/env bash"
    "set -euo pipefail"
    "printf '%s\\n' \"\$*\" >> \"${TEST_TMPDIR}/kubectl.log\""
  )
  lines+=("${KUBECTL_STUB_PRELUDE[@]+"${KUBECTL_STUB_PRELUDE[@]}"}")
  lines+=("case \"\$*\" in")
  lines+=("${KUBECTL_STUB_ARMS[@]+"${KUBECTL_STUB_ARMS[@]}"}")
  lines+=("  *) ${catch_all} ;;" "esac")
  write_stub kubectl "${lines[@]}"
}

# ── the other tools ──────────────────────────────────────────────────────────

# stub_terraform [verbs] -- verbs is a case pattern of the terraform commands
# this script is expected to drive, so an unexpected one still fails.
stub_terraform() {
  local verbs=${1:-"init|destroy|apply"}
  write_stub terraform \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\\n' \"\$*\" >> \"${TEST_TMPDIR}/terraform.log\"" \
"case \"\$2\" in" \
"  ${verbs}) exit 0 ;;" \
"  output)" \
"    case \"\$4\" in" \
"      cluster_name) printf '%s\\n' 'gpu-inference' ;;" \
"      aws_region) printf '%s\\n' 'us-west-2' ;;" \
"      vpc_id) printf '%s\\n' 'vpc-12345' ;;" \
"      aws_load_balancer_controller_role_arn) printf '%s\\n' 'arn:aws:iam::123456789012:role/alb-controller' ;;" \
"      *) exit 1 ;;" \
"    esac" \
"    ;;" \
"  *) exit 1 ;;" \
"esac"
}

stub_helm_teardown() {
  write_stub helm \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\\n' \"\$*\" >> \"${TEST_TMPDIR}/helm.log\"" \
"case \"\$1\" in" \
"  status|uninstall) exit 0 ;;" \
"  *) exit 1 ;;" \
"esac"
}

stub_aws_no_load_balancers() {
  write_stub aws \
"#!/usr/bin/env bash" \
"set -euo pipefail" \
"printf '%s\\n' \"\$*\" >> \"${TEST_TMPDIR}/aws.log\"" \
"case \"\$1 \$2\" in" \
"  'eks update-kubeconfig') exit 0 ;;" \
"  'elbv2 describe-load-balancers') printf '%s\\n' '0' ;;" \
"  *) exit 1 ;;" \
"esac"
}
