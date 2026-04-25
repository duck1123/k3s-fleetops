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
# Full pipeline: generate manifests, post-process, write to manifests/dev/, activate
bb switch-charts

# CI shorthand — same as switch-charts (depends on it)
bb ci

# Generate manifests into manifests/dev/ without activating (no secrets needed)
bb build-charts          # wraps: nixidy build .#dev

# Post-process already-generated manifests (fixups for nixidy hardcoded behaviours)
bb post-process-manifests

# Update vendored Helm chart archives from OCI registries
bb update-charts

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
bb forward-traefik-dashboard     # Expose Traefik dashboard on localhost:9000
bb install-argocd                # Install or upgrade ArgoCD into the cluster (safe to re-run)
bb update-argocd-manifest        # Download latest stable ArgoCD install manifest
bb install-sealed-key            # Upload sealed-secrets TLS keypair (tls.crt + tls.key required)
bb apply-sealed-key-label        # Mark uploaded key as active
bb apply-git-hooks               # Register git hooks for this repo
```

### Database

```sh
bb postgres-list                 # List PostgreSQL databases
bb postgres-list-backups         # List available backups on the postgresql-backups PVC
bb postgres-backup               # Backup (DATABASE=name or all); OUTPUT_DIR optional
bb postgres-restore              # Restore (BACKUP_FILE=... DATABASE=... RECREATE=true)
bb mariadb-list-backups
BACKUP_FILE=filename.sql.gz bb mariadb-restore
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
| `applications/` | One `.nix` file per service (e.g. `sonarr.nix`), each using `self.lib.mkArgoApp`; complex apps may use a subdir with `default.nix` |
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

1. Create `applications/<name>.nix` using `self.lib.mkArgoApp` (see `applications/sonarr.nix` as a full example; some complex apps use a subdirectory `applications/<name>/default.nix` instead).
2. Add the import to `applications/default.nix`.
3. Enable and configure the service in `env/dev.nix` under `services.<name>`.
4. Run `bb switch-charts` to regenerate and apply manifests.

### Apps Without a Dockerfile (nix-csi)

When an upstream project has no Dockerfile, use the nix-csi CSI driver (already deployed) to build and run the binary:

- Set the container `image` to `ghcr.io/lillecarl/nix-csi/scratch:1.0.1`
- Add a `csi` volume with `driver: nix.csi.store` and a `nixExpr` attribute containing a Nix expression that evaluates to the package derivation
- Mount the volume at `/nix` with `subPath: nix` — this makes `/nix/var/result/bin` available on PATH inside the container
- See `applications/demo.nix` for a working example and `applications/nostrarchives.nix` for a Rust app pattern

### `mkArgoApp` Pattern

`modules/lib/mkArgoApp.nix` is the central abstraction. It accepts:
- `name` — sets the ArgoCD application name and Kubernetes namespace
- `chart` — optional Helm chart (from `nixhelm` or `chart-archives/`)
- `extraOptions` — NixOS-style module options exposed under `config.services.<name>`
- `extraResources` — raw Kubernetes resources (deployments, services, ingresses, PVCs, etc.)
- `sopsSecrets` — secrets to encrypt and inject as Kubernetes Secrets
- `uses-ingress` — adds standard ingress options (domain, clusterIssuer, ingressClassName)

### Secrets at Build Time

`env/dev.nix` calls `self.lib.loadSecrets` which reads `$DECRYPTED_SECRET_FILE` (set by `with-decrypted-secrets.sh`). The `bb switch-charts` task calls that wrapper script internally — callers just run `bb switch-charts` or `bb ci` directly.

### Nix Flake Inputs

Key inputs: `nixidy` (GitOps manifest generator), `nixhelm` (Helm chart derivations), `sops-nix`, `flake-parts`, `import-tree`, `make-shell`.

## Dev Environment

Enter the Nix dev shell for all required tools (kubectl, helm, argocd, sops, age, babashka, kubeseal, etc.):

```sh
nix develop
```

Environment variables are managed via `.envrc` (direnv). Copy `.envrc.example` → `.envrc` and run `direnv allow`.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **k3s-fleetops** (826 symbols, 810 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/k3s-fleetops/context` | Codebase overview, check index freshness |
| `gitnexus://repo/k3s-fleetops/clusters` | All functional areas |
| `gitnexus://repo/k3s-fleetops/processes` | All execution flows |
| `gitnexus://repo/k3s-fleetops/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
