{ pkgs, ... }:
pkgs.writeShellScriptBin "post-process-manifests" ''
  set -euo pipefail

  # Prometheus admission webhook: patch Jobs and ensure RBAC stays (Role/RoleBinding grant secret create permission)
  PROM_MANIFESTS_DIR="manifests/dev/prometheus"
  for job in "Job-prometheus-kube-prometheus-admission-create.yaml" "Job-prometheus-kube-prometheus-admission-patch.yaml"; do
    if [ -f "$PROM_MANIFESTS_DIR/$job" ]; then
      ${pkgs.yq-go}/bin/yq eval -i '.spec.ttlSecondsAfterFinished = 300' "$PROM_MANIFESTS_DIR/$job"
      echo "Patched $job: ttlSecondsAfterFinished=300 (gives ArgoCD time to see completion)"
    fi
  done
  # Ensure admission RBAC exists - the create Job needs Role/RoleBinding to create the TLS secret.
  # If the chart didn't emit them (or they were previously removed), create them.
  ROLE_FILE="$PROM_MANIFESTS_DIR/Role-prometheus-kube-prometheus-admission.yaml"
  ROLEBINDING_FILE="$PROM_MANIFESTS_DIR/RoleBinding-prometheus-kube-prometheus-admission.yaml"
  if [ ! -f "$ROLE_FILE" ]; then
    cat > "$ROLE_FILE" << 'ROLEEOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prometheus-kube-prometheus-admission
  namespace: prometheus
  labels:
    app.kubernetes.io/component: prometheus-operator-webhook
    app.kubernetes.io/instance: prometheus
    app.kubernetes.io/name: kube-prometheus-stack-prometheus-operator
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "patch", "delete"]
ROLEEOF
    echo "Created $ROLE_FILE (admission Job needs this to create TLS secret)"
  fi
  if [ ! -f "$ROLEBINDING_FILE" ]; then
    cat > "$ROLEBINDING_FILE" << 'RBEOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prometheus-kube-prometheus-admission
  namespace: prometheus
  labels:
    app.kubernetes.io/component: prometheus-operator-webhook
    app.kubernetes.io/instance: prometheus
    app.kubernetes.io/name: kube-prometheus-stack-prometheus-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: prometheus-kube-prometheus-admission
subjects:
  - kind: ServiceAccount
    name: prometheus-kube-prometheus-admission
    namespace: prometheus
RBEOF
    echo "Created $ROLEBINDING_FILE (binds Role to admission ServiceAccount)"
  fi

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
