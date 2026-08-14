# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitOps-based Kubernetes cluster configuration. ArgoCD manages the cluster by syncing manifests from the `manifests/dev/` directory (the `master` branch). Manifests are generated from Nix/nixidy configuration — never edit files in `manifests/` directly.

## Key Commands

All primary dev commands use [nur](https://github.com/nickel-org/nur) (`nur`), a Nushell task runner. Tasks are defined in `scripts/nur.nu`. List all available tasks:

```sh
nur --help
```

### Build & Deploy

```sh
# Build the nixidy activation package without applying it (like `nixos-rebuild build`)
nur build

# Full pipeline: build, then switch — generate manifests, post-process, write to manifests/dev/, activate
nur switch

# CI shorthand — same as switch
nur ci

# Post-process already-generated manifests (fixups for nixidy hardcoded behaviours)
nur post-process-manifests

# Nix code formatting
nur format

# Run an npm/Vite site app's local dev server — see applications/duck1123-site/
nur preview <name>
```

### Secrets

Secrets are stored encrypted in `secrets.enc.yaml` (sops + age). **Never commit decrypted secrets.**

```sh
# Edit encrypted secrets in-place (preferred)
nur secrets edit

# Decrypt to temp file and run a command with DECRYPTED_SECRET_FILE set
./scripts/with-decrypted-secrets.sh <command>

# Decrypt to file / encrypt back
nur secrets decrypt   # → secrets.yaml (plaintext, do not commit)
nur secrets encrypt   # → secrets.enc.yaml
```

### Cluster Operations

```sh
kubectl get pods -A                   # Check pod status
nur argocd apply-master               # Register 00-master app with ArgoCD (triggers full sync)
nur forward argocd                    # Port-forward ArgoCD UI to localhost:8080
nur forward traefik                   # Expose Traefik dashboard on localhost:9000
nur argocd install                    # Install or upgrade ArgoCD into the cluster (safe to re-run)
nur argocd update-manifest            # Download latest stable ArgoCD install manifest
nur sealed-secrets install-key        # Upload sealed-secrets TLS keypair (tls.crt + tls.key required)
nur sealed-secrets apply-label        # Mark uploaded key as active
nur apply-git-hooks                   # Register git hooks for this repo
```

### Database

```sh
nur postgres list                                        # List PostgreSQL databases
nur postgres list-backups                               # List available backups on the postgresql-backups PVC
nur postgres backup                                     # Backup (--database name or all); --output-dir optional
nur postgres restore <backup_file>                      # Restore (--database ... --recreate)
nur mariadb list-backups
nur mariadb restore --backup-file filename.sql.gz
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
| `env/dev.nix` | Assembles the dev environment: imports every module under `env/dev/`, loads secrets, sets `ageRecipients`/`nixidy` target config |
| `env/dev/` | One module per service (e.g. `env/dev/sonarr.nix`) setting `services.<name>`; `env/dev/options.nix` declares shared `devDefaults.*` options (domains, clusterIssuer, NAS host/path, enableLogging). Services not currently deployed are configured here too with `enable = false`, ready to flip on |
| `modules/lib/` | Shared Nix library functions (`mkArgoApp`, `loadSecrets`, `createSecret`, etc.) |
| `modules/flake/` | Flake-parts modules wiring everything together |
| `generators/` | CRD option modules (imported at eval time via `crdImports`) |
| `manifests/dev/` | **Generated output** — do not edit manually |
| `infra-manifests/` | Bootstrap-only edn manifests (`00-master.edn`, `argocd/install.yaml`); `nur argocd apply-master`/`nur argocd install` consume these directly (via `jet`) |
| `secrets.enc.yaml` | Sops-encrypted secrets (age key at `~/.config/sops/age/keys.txt`) |

### Adding or Modifying an Application

1. Create `applications/<name>.nix` using `self.lib.mkArgoApp` (see `applications/sonarr.nix` as a full example; some complex apps use a subdirectory `applications/<name>/default.nix` instead).
2. Add the import to `applications/default.nix`.
3. Create `env/dev/<name>.nix` setting `services.<name>` (use `enable = false` if it shouldn't deploy yet). No import edit needed here — `env/dev.nix` auto-imports every file under `env/dev/` via `import-tree`. Use `config.devDefaults.*` for shared domains/clusterIssuer/NAS values, and the `secrets`/`arrDatabases` module args (injected via `_module.args` in `env/dev.nix`) where needed.
4. Run `nur switch` to regenerate and apply manifests.

### Apps Without a Dockerfile (nix-csi)

When an upstream project has no Dockerfile, use the nix-csi CSI driver (already deployed) to build and run the binary:

- Set the container `image` to `ghcr.io/lillecarl/nix-csi/scratch:1.0.1`
- Add a `csi` volume with `driver: nix.csi.store` and a `nixExpr` attribute containing a Nix expression that evaluates to the package derivation
- Mount the volume at `/nix` with `subPath: nix` — this makes `/nix/var/result/bin` available on PATH inside the container
- See `applications/demo.nix` for a working example and `applications/nostrarchives.nix` for a Rust app pattern

### Internet-Facing Apps (Cloudflare Tunnel)

Every ingress in this repo (`uses-ingress = true` via `mkArgoApp`) is LAN/Tailscale-only — Traefik+MetalLB or the Tailscale operator, neither reachable from the public internet. For an app that needs a real public hostname (e.g. `duck1123.com`), use the `cloudflared` app (`applications/cloudflared.nix`) instead of a k8s `Ingress`:

- `cloudflared` is a shared, standalone deployment (own namespace, nix-csi runtime bundling `pkgs.cloudflared` + `pkgs.cacert`) that dials outbound to Cloudflare using a tunnel token (`services.cloudflared.tunnelToken`, sourced from `secrets.cloudflared.tunnelToken` in `secrets.enc.yaml`). No inbound firewall rule or router port-forward is needed.
- Hostname → service routing is **not** configured in Nix — it's set in the Cloudflare Zero Trust dashboard's tunnel "Public Hostname" tab, pointed at the target app's cluster-internal Service DNS name (e.g. `duck1123.duck1123.svc.cluster.local:8080`).
- The target app itself needs no `uses-ingress`, no `Ingress` resource, and no cert-manager involvement — just a plain `ClusterIP` `Service`. TLS terminates at Cloudflare's edge. See `applications/duck1123/default.nix` for a full example (static nix-csi-served site behind the tunnel).
- To add another public hostname on the same tunnel: add its "Public Hostname" route in the Cloudflare dashboard pointing at the new app's Service — no repo changes needed to `cloudflared.nix` itself.

#### Static sites (npm/Vite + nix-csi + flake package)

`duck1123` is the reference pattern for a static frontend with no Dockerfile, following the `applications/<name>-site/` convention:

- `applications/<name>-site/` — a real npm/Vite project (see `applications/duck1123-site/`). Run it locally with `nur preview <name>` (Vite dev server, no cluster involved).
- `modules/pkgs/<name>-site.nix` — a `perSystem` flake module exposing `packages.<name>-site` via `pkgs.buildNpmPackage` (see `modules/pkgs/duck1123-site.nix`); `modules/` is auto-imported so dropping the file in is enough, no manual registration.
- `applications/<name>/default.nix` — nix-csi's `nixExpr` fetches `(builtins.getFlake "github:duck1123/k3s-fleetops").packages.x86_64-linux.<name>-site` (same self-referential-flake pattern as `applications/nostrarchives.nix`) and `symlinkJoin`s it with `pkgs.python3` so the mounted `/nix/var/result` has both the built static files and a Python interpreter to serve them. **This means the built site always reflects the last-pushed commit, not local uncommitted changes** — push before expecting nix-csi to pick up new content.

### `mkArgoApp` Pattern

`modules/lib/mkArgoApp.nix` is the central abstraction. It accepts:
- `name` — sets the ArgoCD application name and Kubernetes namespace
- `chart` — optional Helm chart (from `nixhelm`)
- `extraOptions` — NixOS-style module options exposed under `config.services.<name>`
- `extraResources` — raw Kubernetes resources (deployments, services, ingresses, PVCs, etc.)
- `sopsSecrets` — secrets to encrypt and inject as Kubernetes Secrets
- `uses-ingress` — adds standard ingress options (domain, clusterIssuer, ingressClassName)

### Secrets at Build Time

`env/dev.nix` calls `self.lib.loadSecrets` which reads `$DECRYPTED_SECRET_FILE` (set by `with-decrypted-secrets.sh`). The `nur switch` task calls that wrapper script internally — callers just run `nur switch` directly.

### Nix Flake Inputs

Key inputs: `nixidy` (GitOps manifest generator), `nixhelm` (Helm chart derivations), `sops-nix`, `flake-parts`, `import-tree`, `make-shell`.

## Dev Environment

Enter the Nix dev shell for all required tools (kubectl, helm, argocd, sops, age, kubeseal, etc.):

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
