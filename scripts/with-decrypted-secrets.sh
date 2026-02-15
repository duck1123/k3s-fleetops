#!/usr/bin/env bash
# Decrypt secrets/secrets.enc.yaml to a temporary file, set DECRYPTED_SECRET_FILE,
# run the given command, then remove the temp file. No decrypted file is left on disk.
#
# Usage:
#   ./scripts/with-decrypted-secrets.sh bb switch-charts
#   ./scripts/with-decrypted-secrets.sh nix build .#nixidyEnvs.x86_64-linux.dev.activationPackage --impure --no-link --print-out-paths
#
# Optional: SECRETS_ENC_FILE=path/to/enc.yaml to use a different encrypted file (default: secrets/secrets.enc.yaml).
# Requires: sops, SOPS_AGE_KEY_FILE (or your usual sops auth) so sops --decrypt works.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENCRYPTED="${SECRETS_ENC_FILE:-secrets/secrets.enc.yaml}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  echo "  Decrypts $ENCRYPTED to a temp file, sets DECRYPTED_SECRET_FILE, runs the command." >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/$ENCRYPTED" ]]; then
  echo "Encrypted secrets file not found: $REPO_ROOT/$ENCRYPTED" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

sops --decrypt "$REPO_ROOT/$ENCRYPTED" > "$TMP"
export DECRYPTED_SECRET_FILE="$TMP"
cd "$REPO_ROOT"
exec "$@"
