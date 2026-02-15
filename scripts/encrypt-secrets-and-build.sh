#!/usr/bin/env bash
# One-command CI: encrypt secrets (from env) then run the same nix build.
# Keeps plaintext out of the Nix store.
#
# Usage:
#   Export one env var per secret: SOPS_<secretName> = JSON object of stringData.
#   Example: SOPS_RADARR_DATABASE_PASSWORD='{"password":"mypass"}'
#   (Replace - with _ in the env var name.)
#
#   Then either:
#     ./scripts/encrypt-secrets-and-build.sh
#   or from CI (e.g. bb):
#     nix run .#devSecretManifest --raw --apply 'x: builtins.toJSON x' | ./scripts/encrypt-secrets-and-build.sh
#
# If no manifest is piped, the script will try: nix eval .#devSecretManifest --raw --apply 'x: builtins.toJSON x'
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGE_RECIPIENTS="${AGE_RECIPIENTS:-}"
SECRETS_DIR="${SECRETS_DIR:-}"
# Same build as bb: nix build dev activationPackage (optionally via nix-output-monitor)
BUILD_CMD="${BUILD_CMD:-nix build .#nixidyEnvs.x86_64-linux.dev.activationPackage --impure --no-link --print-out-paths}"

if [[ -z "$AGE_RECIPIENTS" ]]; then
  echo "AGE_RECIPIENTS is not set (age public key for sops). Set it or source your env." >&2
  exit 1
fi

if [[ -z "$SECRETS_DIR" ]]; then
  SECRETS_DIR="$(mktemp -d)"
  trap "rm -rf $SECRETS_DIR" EXIT
fi
mkdir -p "$SECRETS_DIR"

# Read manifest: stdin, or build the manifest package
if [[ -t 0 ]]; then
  OUT="$(nix build '.#packages.x86_64-linux.devSecretManifest' --no-link --print-out-paths 2>/dev/null)" || true
  if [[ -n "$OUT" ]]; then
    MANIFEST_JSON="$(cat "$OUT")"
  fi
  if [[ -z "$MANIFEST_JSON" || "$MANIFEST_JSON" == "[]" ]]; then
    echo "No secret manifest (empty or build failed). Running build without pre-encrypted secrets." >&2
    export NIXIFY_PRE_ENCRYPTED_SECRETS_DIR=""
    cd "$REPO_ROOT" && eval "$BUILD_CMD"
    exit 0
  fi
else
  MANIFEST_JSON="$(cat)"
fi

# Encrypt each secret: expect SOPS_<secretName> (replace - with _) = JSON stringData.
# Output format must match createSecret: { sops, spec } as JSON.
encrypt_one() {
  local secretName="$1"
  local namespace="$2"
  local envVarName
  envVarName="SOPS_${secretName//-/_}"
  envVarName="${envVarName^^}"
  local jsonVal="${!envVarName:-}"
  if [[ -z "$jsonVal" ]]; then
    echo "Warning: $envVarName not set, skipping secret $secretName" >&2
    return 1
  fi
  local yamlFile="$SECRETS_DIR/${secretName}.yaml"
  local outFile="$SECRETS_DIR/${secretName}.json"
  # Build full SopsSecret as JSON then YAML (same shape as createSecret)
  jq -n \
    --arg name "$secretName" \
    --arg ns "$namespace" \
    --argjson stringData "$jsonVal" \
    '{apiVersion: "isindir.github.com/v1alpha3", kind: "SopsSecret", metadata: {name: $name, namespace: $ns}, spec: {secretTemplates: [{name: $name, stringData: $stringData}]}}' \
    | yq -y . > "$yamlFile"
  sops --encrypt --age "$AGE_RECIPIENTS" --encrypted-regex='^(stringData)$' "$yamlFile" | yq . > "$outFile"
  rm -f "$yamlFile"
  return 0
}

export AGE_RECIPIENTS SECRETS_DIR
encrypted_count=0
while read -r entry; do
  secretName="$(echo "$entry" | jq -r '.secretName')"
  namespace="$(echo "$entry" | jq -r '.namespace')"
  if encrypt_one "$secretName" "$namespace"; then
    : $((encrypted_count += 1))
  fi
done < <(echo "$MANIFEST_JSON" | jq -c '.[]')

# Only use pre-encrypted dir if we actually wrote secrets (avoids empty dir and fallback to createSecret)
if [[ "$encrypted_count" -gt 0 ]]; then
  export NIXIFY_PRE_ENCRYPTED_SECRETS_DIR="$SECRETS_DIR"
else
  export NIXIFY_PRE_ENCRYPTED_SECRETS_DIR=""
  echo "No SOPS_* env vars set; build will use createSecret (plaintext may be in store)." >&2
fi
cd "$REPO_ROOT" && eval "$BUILD_CMD"
