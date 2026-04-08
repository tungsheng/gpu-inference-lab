#!/usr/bin/env bash

apply_observability_manifests() {
  kubectl apply -f "${OBSERVABILITY_VLLM_PODMONITOR_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_KARPENTER_PODMONITOR_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_PUSHGATEWAY_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_DCGM_EXPORTER_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_SERVING_DASHBOARD_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_CAPACITY_DASHBOARD_MANIFEST}"
  kubectl apply -f "${OBSERVABILITY_EXPERIMENT_DASHBOARD_MANIFEST}"
}

delete_observability_manifests() {
  kubectl delete -f "${OBSERVABILITY_EXPERIMENT_DASHBOARD_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_CAPACITY_DASHBOARD_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_SERVING_DASHBOARD_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_DCGM_EXPORTER_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_PUSHGATEWAY_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_KARPENTER_PODMONITOR_MANIFEST}" --ignore-not-found=true
  kubectl delete -f "${OBSERVABILITY_VLLM_PODMONITOR_MANIFEST}" --ignore-not-found=true
}

install_kube_prometheus_stack() {
  run_step "adding Prometheus community Helm repository" \
    helm repo add "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}" "${PROMETHEUS_COMMUNITY_HELM_REPO_URL}" --force-update
  run_step "updating Helm repository metadata" helm repo update
  run_step "installing kube-prometheus-stack" \
    helm upgrade --install "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" \
      "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}/kube-prometheus-stack" \
      -n "${MONITORING_NAMESPACE}" \
      --create-namespace \
      --wait \
      --timeout 15m \
      --version "${KUBE_PROMETHEUS_STACK_CHART_VERSION}" \
      -f "${OBSERVABILITY_KUBE_PROMETHEUS_STACK_VALUES}"
  run_step "waiting for Prometheus operator rollout" \
    kubectl rollout status "deployment/${KUBE_PROMETHEUS_STACK_OPERATOR_DEPLOYMENT}" -n "${MONITORING_NAMESPACE}" --timeout=10m
  run_step "waiting for Grafana rollout" \
    kubectl rollout status "deployment/${KUBE_PROMETHEUS_STACK_GRAFANA_DEPLOYMENT}" -n "${MONITORING_NAMESPACE}" --timeout=10m
  run_step "waiting for Prometheus rollout" \
    kubectl rollout status "statefulset/${KUBE_PROMETHEUS_STACK_PROMETHEUS_STATEFULSET}" -n "${MONITORING_NAMESPACE}" --timeout=10m
}

install_prometheus_adapter() {
  run_step "installing Prometheus Adapter" \
    helm upgrade --install "${PROMETHEUS_ADAPTER_RELEASE_NAME}" \
      "${PROMETHEUS_COMMUNITY_HELM_REPO_NAME}/prometheus-adapter" \
      -n "${MONITORING_NAMESPACE}" \
      --create-namespace \
      --wait \
      --timeout 10m \
      --version "${PROMETHEUS_ADAPTER_CHART_VERSION}" \
      -f "${OBSERVABILITY_PROMETHEUS_ADAPTER_VALUES}"
  run_step "waiting for Prometheus Adapter rollout" \
    kubectl rollout status "deployment/${PROMETHEUS_ADAPTER_DEPLOYMENT_NAME}" -n "${MONITORING_NAMESPACE}" --timeout=10m
  run_step "waiting for the custom metrics API" \
    wait_for_apiservice_available "${PROMETHEUS_ADAPTER_APISERVICE_NAME}" 300
}

install_observability_stack() {
  install_kube_prometheus_stack
  run_step "applying observability monitors, exporters, and dashboards" apply_observability_manifests
  run_step "waiting for Pushgateway deployment to be present" \
    wait_for_resource_existence deployment "${PUSHGATEWAY_DEPLOYMENT_NAME}" "${MONITORING_NAMESPACE}" 60
  run_step "waiting for Pushgateway rollout" \
    kubectl rollout status "deployment/${PUSHGATEWAY_DEPLOYMENT_NAME}" -n "${MONITORING_NAMESPACE}" --timeout=5m
  run_step "waiting for DCGM exporter daemonset to be present" \
    wait_for_resource_existence daemonset "${DCGM_EXPORTER_DAEMONSET_NAME}" "${MONITORING_NAMESPACE}" 60
  install_prometheus_adapter
}

delete_observability_stack() {
  if namespace_exists "${MONITORING_NAMESPACE}"; then
    run_step "deleting observability monitors, exporters, and dashboards" delete_observability_manifests
  fi

  if helm status "${PROMETHEUS_ADAPTER_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
    run_step "uninstalling Prometheus Adapter" \
      helm uninstall "${PROMETHEUS_ADAPTER_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" --wait
  fi

  if resource_exists apiservice "${PROMETHEUS_ADAPTER_APISERVICE_NAME}"; then
    run_step "waiting for custom metrics API deletion" \
      wait_for_resource_deletion apiservice "${PROMETHEUS_ADAPTER_APISERVICE_NAME}" "" 300
  fi

  if helm status "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
    run_step "uninstalling kube-prometheus-stack" \
      helm uninstall "${KUBE_PROMETHEUS_STACK_RELEASE_NAME}" -n "${MONITORING_NAMESPACE}" --wait
  fi

  if namespace_exists "${MONITORING_NAMESPACE}"; then
    run_step "deleting monitoring namespace" kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found=true
    run_step "waiting for monitoring namespace deletion" wait_for_resource_deletion namespace "${MONITORING_NAMESPACE}" "" 300
  fi
}
