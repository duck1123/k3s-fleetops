{ pkgs, ... }:
pkgs.writeShellScriptBin "post-process-manifests" ''
  set -euo pipefail

  MANIFESTS_DIR="manifests/dev/amd-gpu-device-plugin"
  
  # Remove kube-system namespace resource - it's a protected system namespace
  # that shouldn't be managed by ArgoCD
  if [ -f "$MANIFESTS_DIR/Namespace-kube-system.yaml" ]; then
    echo "Removing kube-system namespace resource - it's a protected system namespace"
    rm -f "$MANIFESTS_DIR/Namespace-kube-system.yaml"
  fi
  
  # Remove CreateNamespace=true from Application syncOptions
  # This prevents ArgoCD from trying to manage the kube-system namespace
  APP_FILE="manifests/dev/apps/Application-amd-gpu-device-plugin.yaml"
  if [ -f "$APP_FILE" ] && grep -q "CreateNamespace=true" "$APP_FILE"; then
    # Use sed to remove the syncOptions section
    # Match from "syncOptions:" line through the "CreateNamespace=true" line
    sed -i '/^[[:space:]]*syncOptions:/,/^[[:space:]]*- CreateNamespace=true$/d' "$APP_FILE"
    echo "Removed CreateNamespace=true from Application syncOptions"
  fi
''

