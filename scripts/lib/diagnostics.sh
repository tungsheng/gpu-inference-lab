#!/usr/bin/env bash

print_cluster_context_diagnostics() {
  kubectl config current-context >&2 || true
  kubectl get nodes -L workload,node.kubernetes.io/instance-type -o wide >&2 || true
}

print_kube_system_diagnostics() {
  kubectl get pods -n kube-system -o wide >&2 || true
  kubectl get deployment "${AWS_LOAD_BALANCER_CONTROLLER_RELEASE_NAME}" -n kube-system -o wide >&2 || true
  kubectl get deployment "${METRICS_SERVER_DEPLOYMENT_NAME}" -n kube-system -o wide >&2 || true
}

print_nvidia_diagnostics() {
  if resource_exists daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" kube-system; then
    kubectl get daemonset "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_NAME}" -n kube-system -o wide >&2 || true
  fi
  kubectl get pods -n kube-system -l "${NVIDIA_DEVICE_PLUGIN_POD_SELECTOR}" -o wide >&2 || true
}

print_app_namespace_diagnostics() {
  if ! namespace_exists "${APP_NAMESPACE}"; then
    return 0
  fi

  kubectl get deployment -n "${APP_NAMESPACE}" >&2 || true
  kubectl get service -n "${APP_NAMESPACE}" >&2 || true
  kubectl get ingress -n "${APP_NAMESPACE}" >&2 || true
  kubectl get hpa -n "${APP_NAMESPACE}" >&2 || true
}

print_karpenter_diagnostics() {
  if namespace_exists "${KARPENTER_NAMESPACE}"; then
    kubectl get pods -n "${KARPENTER_NAMESPACE}" -o wide >&2 || true
    kubectl get deployment "${KARPENTER_RELEASE_NAME}" -n "${KARPENTER_NAMESPACE}" -o wide >&2 || true
    helm list -n "${KARPENTER_NAMESPACE}" >&2 || true
  fi

  if api_resource_exists "nodepools.karpenter.sh"; then
    kubectl get nodepools >&2 || true
  fi
  if api_resource_exists "nodeclaims.karpenter.sh"; then
    kubectl get nodeclaims >&2 || true
  fi
  if api_resource_exists "ec2nodeclasses.karpenter.k8s.aws"; then
    kubectl get ec2nodeclasses >&2 || true
  fi
}

print_aws_load_balancer_controller_diagnostics() {
  if api_resource_exists "targetgroupbindings.elbv2.k8s.aws"; then
    kubectl get targetgroupbindings -A >&2 || true
  fi
  if api_resource_exists "ingressclassparams.elbv2.k8s.aws"; then
    kubectl get ingressclassparams >&2 || true
  fi
  helm list -n kube-system >&2 || true
}

print_recent_event_diagnostics() {
  kubectl get events -A --sort-by=.metadata.creationTimestamp >&2 || true
}

print_apply_diagnostics() {
  log_warn "collecting Kubernetes diagnostics"
  print_cluster_context_diagnostics
  print_kube_system_diagnostics
  print_karpenter_diagnostics
  print_nvidia_diagnostics
  print_app_namespace_diagnostics
  print_recent_event_diagnostics
}

print_destroy_diagnostics() {
  log_warn "collecting teardown diagnostics"
  print_cluster_context_diagnostics
  print_app_namespace_diagnostics
  print_kube_system_diagnostics
  print_nvidia_diagnostics
  print_aws_load_balancer_controller_diagnostics
  print_karpenter_diagnostics
}
