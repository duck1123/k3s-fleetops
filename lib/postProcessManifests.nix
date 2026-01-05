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

  # Add compare-options annotation to ignore extraneous resources (like kube-system namespace)
  # This prevents ArgoCD from tracking resources that exist in cluster but not in manifests
  # Using annotation instead of spec.compareOptions as it's more reliable
  if [ -f "$APP_FILE" ]; then
    # Check if the annotation already exists
    if ! grep -q "argocd.argoproj.io/compare-options" "$APP_FILE"; then
      # Use yq-go to add the annotation
      ${pkgs.yq-go}/bin/yq eval -i '.metadata.annotations."argocd.argoproj.io/compare-options" = "IgnoreExtraneous"' "$APP_FILE"
      echo "Added compare-options annotation to Application"
    elif ! grep -q "IgnoreExtraneous" "$APP_FILE"; then
      # Update existing annotation to include IgnoreExtraneous
      ${pkgs.yq-go}/bin/yq eval -i '.metadata.annotations."argocd.argoproj.io/compare-options" = "IgnoreExtraneous"' "$APP_FILE"
      echo "Updated compare-options annotation to IgnoreExtraneous"
    fi
    # Remove compareOptions from spec if it exists (we're using annotation instead)
    if ${pkgs.yq-go}/bin/yq eval '.spec.compareOptions' "$APP_FILE" 2>/dev/null | grep -q "."; then
      ${pkgs.yq-go}/bin/yq eval -i 'del(.spec.compareOptions)' "$APP_FILE"
      echo "Removed compareOptions from spec (using annotation instead)"
    fi
  fi

  # Add ignoreDifferences for kube-system namespace as a backup
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

  # Create kube-system namespace manifest with annotations to prevent ArgoCD from managing it
  # This tells ArgoCD the namespace exists but shouldn't be pruned or synced
  NS_FILE="$MANIFESTS_DIR/Namespace-kube-system.yaml"
  if [ ! -f "$NS_FILE" ]; then
    # Create the namespace manifest with Prune=false annotation
    cat > "$NS_FILE" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
    argocd.argoproj.io/compare-options: IgnoreExtraneous
EOF
    echo "Created kube-system namespace manifest with Prune=false annotation"
  else
    # Ensure the annotations are present
    if ! grep -q "argocd.argoproj.io/sync-options" "$NS_FILE"; then
      ${pkgs.yq-go}/bin/yq eval -i '.metadata.annotations."argocd.argoproj.io/sync-options" = "Prune=false"' "$NS_FILE"
      echo "Added Prune=false annotation to existing namespace manifest"
    fi
    if ! grep -q "argocd.argoproj.io/compare-options" "$NS_FILE"; then
      ${pkgs.yq-go}/bin/yq eval -i '.metadata.annotations."argocd.argoproj.io/compare-options" = "IgnoreExtraneous"' "$NS_FILE"
      echo "Added compare-options annotation to existing namespace manifest"
    fi
  fi
''

