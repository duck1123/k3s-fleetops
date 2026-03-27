# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitOps-based Kubernetes cluster configuration. ArgoCD manages the cluster by syncing manifests from the `manifests/dev/` directory (the `master` branch). Manifests are generated from Nix/nixidy configuration — never edit files in `manifests/` directly.

## Key Commands

All primary dev commands use [Babashka](https://babashka.org/) (`bb`). List all available tasks:

```sh
bb tasks
```

### Build & Deploy

```sh
# Build nixidy manifests (full pipeline: nix build + post-process + activate)
./scripts/with-decrypted-secrets.sh bb switch-charts

# Build nixidy charts only (without activating)
nixidy build .#dev

# Nix code formatting
bb format
```

### Secrets

Secrets are stored encrypted in `secrets.enc.yaml` (sops + age). **Never commit decrypted secrets.**

```sh
# Edit encrypted secrets in-place (preferred)
sops secrets.enc.yaml
# or: bb edit-secrets

# Decrypt to temp file and run a command with DECRYPTED_SECRET_FILE set
./scripts/with-decrypted-secrets.sh <command>

# Decrypt to file / encrypt back
bb decrypt   # → secrets.yaml (plaintext, do not commit)
bb encrypt   # → secrets.enc.yaml
```

### Cluster Operations

```sh
kubectl get pods -A              # Check pod status
bb apply-master-application      # Register 00-master app with ArgoCD (triggers full sync)
bb forward-argocd                # Port-forward ArgoCD UI to localhost:8080
bb install-sealed-key            # Upload sealed-secrets TLS keypair (tls.crt + tls.key required)
bb apply-sealed-key-label        # Mark uploaded key as active
```

### Database

```sh
bb postgres-list                 # List PostgreSQL databases
bb postgres-backup               # Backup (DATABASE=name or all); OUTPUT_DIR optional
bb postgres-restore              # Restore (BACKUP_FILE=... DATABASE=... RECREATE=true)
bb mariadb-list-backups
BACKUP_FILE=filename.sql.gz bb mariadb-restore
```

### Dev Cluster (k3d)

```sh
bbg k3d-create-registry         # Create local k3d registry
bbg k3d-create                  # Create k3d cluster
k3d cluster delete               # Destroy dev cluster
```

## Architecture

### GitOps Flow

```
env/dev.nix + applications/**  →  nixidy build  →  manifests/dev/  →  ArgoCD sync  →  cluster
```

ArgoCD is bootstrapped manually (see README), then self-manages via the `00-master` Application in `manifests/dev/apps/`.

### Directory Structure

| Path | Purpose |
|------|---------|
| `applications/` | One subdir per service; each has a `default.nix` using `self.lib.mkArgoApp` |
| `env/dev.nix` | Single dev environment config: enables/disables services, sets domains, loads secrets |
| `modules/lib/` | Shared Nix library functions (`mkArgoApp`, `loadSecrets`, `createSecret`, etc.) |
| `modules/flake/` | Flake-parts modules wiring everything together |
| `generators/` | CRD option modules (imported at eval time via `crdImports`) |
| `manifests/dev/` | **Generated output** — do not edit manually |
| `infra-manifests/` | Legacy edn-based manifests (`00-master.edn`); used by `bb apply-master-application` |
| `chart-archives/` | Vendored Helm chart `.tgz` files (managed by `bb update-charts`) |
| `src/k3s_fleetops/` | Babashka Clojure source for bb tasks (`postgres.clj`) |
| `secrets.enc.yaml` | Sops-encrypted secrets (age key at `~/.config/sops/age/keys.txt`) |

### Adding or Modifying an Application

1. Create `applications/<name>/default.nix` using `self.lib.mkArgoApp` (see `applications/sonarr/default.nix` as a full example).
2. Add the import to `applications/default.nix`.
3. Enable and configure the service in `env/dev.nix` under `services.<name>`.
4. Run `./scripts/with-decrypted-secrets.sh bb switch-charts` to regenerate and apply manifests.

### `mkArgoApp` Pattern

`modules/lib/mkArgoApp.nix` is the central abstraction. It accepts:
- `name` — sets the ArgoCD application name and Kubernetes namespace
- `chart` — optional Helm chart (from `nixhelm` or `chart-archives/`)
- `extraOptions` — NixOS-style module options exposed under `config.services.<name>`
- `extraResources` — raw Kubernetes resources (deployments, services, ingresses, PVCs, etc.)
- `sopsSecrets` — secrets to encrypt and inject as Kubernetes Secrets
- `uses-ingress` — adds standard ingress options (domain, clusterIssuer, ingressClassName)

### Secrets at Build Time

`env/dev.nix` calls `self.lib.loadSecrets` which reads `$DECRYPTED_SECRET_FILE` (set by `with-decrypted-secrets.sh`). Any `bb switch-charts` invocation must go through that wrapper script.

### Nix Flake Inputs

Key inputs: `nixidy` (GitOps manifest generator), `nixhelm` (Helm chart derivations), `sops-nix`, `flake-parts`, `import-tree`, `make-shell`.

## Dev Environment

Enter the Nix dev shell for all required tools (kubectl, helm, argocd, sops, age, babashka, kubeseal, etc.):

```sh
nix develop
```

Environment variables are managed via `.envrc` (direnv). Copy `.envrc.example` → `.envrc` and run `direnv allow`.
