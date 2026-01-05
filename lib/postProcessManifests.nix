{ pkgs, ... }:
pkgs.writeShellScriptBin "post-process-manifests" ''
  set -euo pipefail

  MANIFESTS_DIR="manifests/dev/amd-gpu-device-plugin"
  APP_FILE="manifests/dev/apps/Application-amd-gpu-device-plugin.yaml"

  # Remove CreateNamespace=true from Application syncOptions
  # This prevents ArgoCD from trying to create the kube-system namespace
  if [ -f "$APP_FILE" ] && grep -q "CreateNamespace=true" "$APP_FILE"; then
    # Use sed to remove the syncOptions section
    # Match from "syncOptions:" line through the "CreateNamespace=true" line
    sed -i '/^[[:space:]]*syncOptions:/,/^[[:space:]]*- CreateNamespace=true$/d' "$APP_FILE"
    echo "Removed CreateNamespace=true from Application syncOptions"
  fi

  # Add ignoreDifferences for kube-system namespace to prevent ArgoCD from trying to prune it
  # This tells ArgoCD to ignore differences for the kube-system namespace
  if [ -f "$APP_FILE" ]; then
    # Check if ignoreDifferences already exists
    if ! grep -q "ignoreDifferences:" "$APP_FILE"; then
      # Use yq-go (Go version) to add ignoreDifferences after destination section
      ${pkgs.yq-go}/bin/yq eval -i '.spec.ignoreDifferences = [{"kind": "Namespace", "name": "kube-system"}]' "$APP_FILE"
      echo "Added ignoreDifferences for kube-system namespace"
    elif ! grep -q "name: kube-system" "$APP_FILE"; then
      # Add kube-system to existing ignoreDifferences using yq-go
      ${pkgs.yq-go}/bin/yq eval -i '.spec.ignoreDifferences += [{"kind": "Namespace", "name": "kube-system"}]' "$APP_FILE"
      echo "Added kube-system to existing ignoreDifferences"
    fi
  fi

  # Remove kube-system namespace manifest - it's a protected system namespace
  # that shouldn't be managed by ArgoCD. The ignoreDifferences above handles this.
  NS_FILE="$MANIFESTS_DIR/Namespace-kube-system.yaml"
  if [ -f "$NS_FILE" ]; then
    rm -f "$NS_FILE"
    echo "Removed kube-system namespace manifest (protected system namespace)"
  fi
''

