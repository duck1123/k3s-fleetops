{ pkgs, ... }:
pkgs.writeShellScriptBin "post-process-manifests" ''
  set -euo pipefail

  # Remove Prometheus admission webhook RBAC resources from manifests
  # These are managed by Helm hooks and shouldn't be synced by ArgoCD
  PROM_MANIFESTS_DIR="manifests/dev/prometheus"
  for job in "Job-prometheus-kube-prometheus-admission-create.yaml" "Job-prometheus-kube-prometheus-admission-patch.yaml"; do
    if [ -f "$PROM_MANIFESTS_DIR/$job" ]; then
      ${pkgs.yq-go}/bin/yq eval -i '.spec.ttlSecondsAfterFinished = 300' "$PROM_MANIFESTS_DIR/$job"
      echo "Patched $job: ttlSecondsAfterFinished=300 (gives ArgoCD time to see completion)"
    fi
  done
  for resource in "Role-prometheus-kube-prometheus-admission.yaml" "RoleBinding-prometheus-kube-prometheus-admission.yaml" "ClusterRole-prometheus-kube-prometheus-admission.yaml" "ClusterRoleBinding-prometheus-kube-prometheus-admission.yaml"; do
    if [ -f "$PROM_MANIFESTS_DIR/$resource" ]; then
      rm -f "$PROM_MANIFESTS_DIR/$resource"
      echo "Removed $resource (managed by Helm hooks)"
    fi
  done

  # Also add ignoreDifferences so Argo does not fight server-injected fields
  PROM_APP_FILE="manifests/dev/apps/Application-prometheus.yaml"
  if [ -f "$PROM_APP_FILE" ]; then
    # RBAC + both webhook configs: caBundle is injected by the API server after apply; ignore to avoid OutOfSync/sync failures
    ${pkgs.yq-go}/bin/yq eval -i '.spec.ignoreDifferences = [
      {"kind": "Role", "name": "prometheus-kube-prometheus-admission", "namespace": "prometheus"},
      {"kind": "RoleBinding", "name": "prometheus-kube-prometheus-admission", "namespace": "prometheus"},
      {"kind": "ClusterRole", "name": "prometheus-kube-prometheus-admission"},
      {"kind": "ClusterRoleBinding", "name": "prometheus-kube-prometheus-admission"},
      {"group": "admissionregistration.k8s.io", "kind": "ValidatingWebhookConfiguration", "name": "prometheus-kube-prometheus-admission", "jqPathExpressions": [".webhooks[].clientConfig.caBundle"]},
      {"group": "admissionregistration.k8s.io", "kind": "MutatingWebhookConfiguration", "name": "prometheus-kube-prometheus-admission", "jqPathExpressions": [".webhooks[].clientConfig.caBundle"]}
    ]' "$PROM_APP_FILE"
    echo "Updated ignoreDifferences for Prometheus admission webhook RBAC and caBundle"
  fi
''
