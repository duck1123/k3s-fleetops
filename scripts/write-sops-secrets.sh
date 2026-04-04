#!/usr/bin/env bash
# Write SopsSecret YAML manifests to manifests/dev/<namespace>/ using sops.
#
# Encryption happens here in the shell, never inside Nix, so plaintext secret
# values never enter the Nix store.
#
# Behaviour:
#   - Reuses committed ciphertext for unchanged secrets (no spurious git diffs).
#   - Encrypts fresh ciphertext for any secret that has no committed manifest.
#   - Deletes SopsSecret-*.yaml files for secrets that are no longer configured.
#
# To force re-encryption of a changed secret value, delete its manifest:
#   rm manifests/dev/<namespace>/SopsSecret-<name>.yaml
#   bb switch-charts
#
# Usage (standalone — handles its own decryption):
#   ./scripts/write-sops-secrets.sh
#
# Required env / files:
#   secrets.enc.yaml  — sops-encrypted secrets file in repo root
#   SOPS_AGE_KEY_FILE or equivalent sops auth for decryption
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests/dev"
SYSTEM="${SYSTEM:-x86_64-linux}"

# ---------------------------------------------------------------------------
# 1. Decrypt secrets so `nix eval --impure` can read them via DECRYPTED_SECRET_FILE
# ---------------------------------------------------------------------------
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [[ ! -f "$REPO_ROOT/secrets.enc.yaml" ]]; then
  echo "write-sops-secrets: secrets.enc.yaml not found, skipping" >&2
  exit 0
fi

sops --decrypt "$REPO_ROOT/secrets.enc.yaml" > "$TMP"
export DECRYPTED_SECRET_FILE="$TMP"

# ---------------------------------------------------------------------------
# 2. Get secret specs (with plaintext values) via nix eval.
#    The result is printed to stdout and piped here — it is NEVER written to
#    a store path, so plaintext stays out of the Nix store.
# ---------------------------------------------------------------------------
cd "$REPO_ROOT"
SPECS_JSON="$(nix eval --impure --json ".#nixidySecretSpecs.${SYSTEM}.dev")"

AGE_RECIPIENTS="$(echo "$SPECS_JSON" | jq -r '.ageRecipients')"
if [[ -z "$AGE_RECIPIENTS" || "$AGE_RECIPIENTS" == "null" ]]; then
  echo "write-sops-secrets: ageRecipients not found in secret specs" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Build a list of desired output paths so we can clean up stale secrets
# ---------------------------------------------------------------------------
declare -A desired_files

while IFS= read -r spec; do
  secret_name="$(echo "$spec" | jq -r '.secretName')"
  namespace="$(echo "$spec" | jq -r '.namespace')"
  desired_files["$MANIFESTS_DIR/$namespace/SopsSecret-${secret_name}.yaml"]=1
done < <(echo "$SPECS_JSON" | jq -c '.secrets[]')

# ---------------------------------------------------------------------------
# 4. Delete SopsSecret files for secrets that no longer exist in the config
# ---------------------------------------------------------------------------
while IFS= read -r existing; do
  if [[ -z "${desired_files[$existing]+_}" ]]; then
    echo "write-sops-secrets: removing stale secret: $existing"
    rm -f "$existing"
  fi
done < <(find "$MANIFESTS_DIR" -name "SopsSecret-*.yaml" 2>/dev/null)

# ---------------------------------------------------------------------------
# 5. Write each desired secret — skip if plaintext values unchanged
# ---------------------------------------------------------------------------
while IFS= read -r spec; do
  secret_name="$(echo "$spec" | jq -r '.secretName')"
  namespace="$(echo "$spec" | jq -r '.namespace')"
  values="$(echo "$spec" | jq '.values')"
  output_file="$MANIFESTS_DIR/$namespace/SopsSecret-${secret_name}.yaml"

  # Check if file exists and compare plaintext values
  if [[ -f "$output_file" ]]; then
    # Decrypt existing file and compare values
    existing_plaintext="$(sops --decrypt --input-type yaml --output-type json "$output_file" | jq '.spec.secretTemplates[0].stringData')"
    if [[ "$existing_plaintext" == "$values" ]]; then
      echo "write-sops-secrets: skipping unchanged secret: $secret_name"
      continue
    fi
  fi

  echo "write-sops-secrets: encrypting $secret_name"

  # Build stringData lines for the YAML
  string_data_lines="$(echo "$values" | jq -r 'to_entries[] | "        \(.key): \(.value | tostring)"')"

  plaintext_yaml="apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
spec:
  secretTemplates:
    - name: ${secret_name}
      stringData:
${string_data_lines}"

  # Encrypt with sops — reads plaintext from stdin, writes encrypted YAML to file
  echo "$plaintext_yaml" \
    | sops --encrypt \
        --age "$AGE_RECIPIENTS" \
        --encrypted-regex '^(stringData)$' \
        --input-type yaml \
        --output-type yaml \
        /dev/stdin \
    > "$output_file"

done < <(echo "$SPECS_JSON" | jq -c '.secrets[]')

echo "write-sops-secrets: done"
