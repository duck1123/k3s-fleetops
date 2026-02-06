{ pkgs, ... }:
pkgs.writeShellScriptBin "post-process-manifests" ''
  set -euo pipefail

  # Remove Prometheus admission webhook RBAC resources from manifests
  # These are managed by Helm hooks and shouldn't be synced by ArgoCD
  PROM_MANIFESTS_DIR="manifests/dev/prometheus"
  for resource in "Role-prometheus-kube-prometheus-admission.yaml" "RoleBinding-prometheus-kube-prometheus-admission.yaml" "ClusterRole-prometheus-kube-prometheus-admission.yaml" "ClusterRoleBinding-prometheus-kube-prometheus-admission.yaml"; do
    if [ -f "$PROM_MANIFESTS_DIR/$resource" ]; then
      rm -f "$PROM_MANIFESTS_DIR/$resource"
      echo "Removed $resource (managed by Helm hooks)"
    fi
  done

  # Also add ignoreDifferences as a backup in case resources are recreated
  PROM_APP_FILE="manifests/dev/apps/Application-prometheus.yaml"
  if [ -f "$PROM_APP_FILE" ]; then
    # Always update ignoreDifferences to ensure it has the correct format with namespace
    ${pkgs.yq-go}/bin/yq eval -i '.spec.ignoreDifferences = [
      {"kind": "Role", "name": "prometheus-kube-prometheus-admission", "namespace": "prometheus"},
      {"kind": "RoleBinding", "name": "prometheus-kube-prometheus-admission", "namespace": "prometheus"},
      {"kind": "ClusterRole", "name": "prometheus-kube-prometheus-admission"},
      {"kind": "ClusterRoleBinding", "name": "prometheus-kube-prometheus-admission"}
    ]' "$PROM_APP_FILE"
    echo "Updated ignoreDifferences for Prometheus admission webhook RBAC resources"
  fi
''
