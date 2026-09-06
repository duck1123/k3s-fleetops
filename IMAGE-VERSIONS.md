# Image & Chart Version Management

This document records all explicitly pinned container images and Helm chart versions, plus the process for checking and updating them. Update this file whenever versions change.

**Last full check: 2026-08-10**

---

## How to update a container image

1. Find the `default = "image:tag"` line in `applications/<name>.nix` (or the `image = "..."` override in `env/dev.nix`).
2. Replace the tag with the new version.
3. Run `nur switch` to regenerate and apply manifests.

No hash is needed — container images pull directly at runtime.

---

## How to update a Helm chart

Charts downloaded via `lib.helm.downloadHelmChart` require both a `version` and a `chartHash` update.

```bash
# 1. Pull the new chart version
helm pull --repo "REPO_URL" CHART_NAME --version NEW_VERSION --untar -d /tmp/helm-dl/

# 2. Compute the NAR hash (must match nix outputHashMode = "recursive")
nix hash path --sri /tmp/helm-dl/CHART_NAME

# 3. Update version and chartHash in applications/<name>.nix
# 4. Run nur switch
```

For **OCI charts** (repo starts with `oci://`), the pull command is:
```bash
helm pull oci://REGISTRY/CHART --version NEW_VERSION --untar -d /tmp/helm-dl/
```

Charts managed via `nixhelm` (argocd, cert-manager, forgejo, grafana, loki, longhorn, metallb, promtail, traefik) are updated by bumping the flake input:
```bash
nix flake update nixhelm
```

---

## Pinned container images

These images have explicit version tags and require manual checks.

| Service | File | Image | Current Tag | Check URL |
|---------|------|-------|-------------|-----------|
| nocodb | applications/nocodb.nix | nocodb/nocodb | 2026.08.0 | https://hub.docker.com/r/nocodb/nocodb/tags |
| paperless-ngx | applications/paperless-ngx.nix | ghcr.io/paperless-ngx/paperless-ngx | 3.1.3 | https://github.com/paperless-ngx/paperless-ngx/releases |
| radarr | env/dev/radarr.nix | linuxserver/radarr | 6.3.0.10514-ls313 | https://hub.docker.com/r/linuxserver/radarr/tags |
| sonarr | env/dev/sonarr.nix | linuxserver/sonarr | 4.0.19.2979-ls321 | https://hub.docker.com/r/linuxserver/sonarr/tags |
| tdarr | env/dev/tdarr.nix | ghcr.io/haveagitgat/tdarr | 2.86.01 | https://github.com/HaveAGitGat/Tdarr (GHCR tags are authoritative; GitHub Releases page is stale) |
| kavita | applications/kavita.nix | linuxserver/kavita | v0.9.0.2-ls110 | https://hub.docker.com/r/linuxserver/kavita/tags |
| mealie | applications/mealie.nix, env/dev/mealie.nix | ghcr.io/mealie-recipes/mealie | v3.22.0 | https://github.com/mealie-recipes/mealie/releases |
| romm | applications/romm.nix | ghcr.io/rommapp/romm | 5.1.0 | https://github.com/rommapp/romm/releases |
| bookorbit | applications/bookorbit.nix | ghcr.io/bookorbit/bookorbit | 1.3.0 | https://github.com/bookorbit/bookorbit/pkgs/container/bookorbit |
| hivemq | applications/hivemq.nix | hivemq/hivemq-ce | 2026.5 | https://hub.docker.com/r/hivemq/hivemq-ce/tags |
| postgres init | applications/immich.nix | docker.io/postgres | 17.10 | https://hub.docker.com/_/postgres/tags |
| pgvector | applications/postgresql.nix | pgvector/pgvector | pg17 (floating) | https://hub.docker.com/r/pgvector/pgvector/tags |
| busybox | various (init containers) | busybox | 1.36 | https://hub.docker.com/_/busybox/tags |
| trilium | applications/trilium.nix | triliumnext/trilium | v0.104.1 | https://github.com/TriliumNext/Trilium/releases |
| hass-AiDot | applications/home-assistant.nix | toxuin/hass-AiDot (git tag, not an image) | v1.2.0 | https://github.com/toxuin/hass-AiDot/releases |
| opensearch | applications/ditto-relay.nix | opensearchproject/opensearch | 2.19.0 | https://hub.docker.com/r/opensearchproject/opensearch/tags |

**Floating images** (no pinning needed — these always pull latest/stable):
Many applications use `:latest`, `:stable`, or a floating major tag (e.g. `redis:8-alpine`, `louislam/uptime-kuma:1`).
These self-update on pod restart and don't require manual tracking.

---

## Helm charts via `downloadHelmChart`

Charts with explicit version pins and SHA-256 hashes.

### Up to date

| Service | File | Repo | Version | ArtifactHub / Source |
|---------|------|------|---------|----------------------|
| authentik | applications/authentik.nix | https://charts.goauthentik.io/ | 2026.5.2 | https://artifacthub.io/packages/helm/goauthentik/authentik |
| cloudbeaver | applications/cloudbeaver.nix | https://avistotelecom.github.io/charts/ | 1.1.7 | https://artifacthub.io/packages/helm/avisto/cloudbeaver |
| immich | applications/immich.nix | oci://ghcr.io/immich-app/immich-charts | 0.12.0 | https://artifacthub.io/packages/helm/immich/immich |
| kite | applications/kite.nix | https://zxh326.github.io/kite | 0.14.1 | https://github.com/kite-org/kite (image repo moved zxh326→kite-org; Helm repo URL still resolves as-is) |
| mariadb | applications/mariadb.nix | oci://registry-1.docker.io/bitnamicharts (classic charts.bitnami.com repo 403s now) | 27.0.4 | https://artifacthub.io/packages/helm/bitnami/mariadb — free-tier image is `bitnami/mariadb:latest` only, no immutable tag; chart appVersion label (13.0.1, an RC) is cosmetic since we pin `image` ourselves |
| memos | applications/memos.nix | https://charts.gabe565.com | 0.17.0 | https://artifacthub.io/packages/helm/gabe565/memos |
| metabase | applications/metabase.nix | https://pmint93.github.io/helm-charts | 2.26.0 | https://artifacthub.io/packages/helm/pmint93/metabase |
| minio | applications/minio.nix | https://charts.bitnami.com/bitnami | 17.0.21 | https://artifacthub.io/packages/helm/bitnami/minio |
| n8n | applications/n8n.nix | https://community-charts.github.io/helm-charts | 1.16.44 | https://artifacthub.io/packages/helm/community-charts/n8n |
| pihole | applications/pihole.nix | https://mojo2600.github.io/pihole-kubernetes/ | 2.38.0 | https://artifacthub.io/packages/helm/mojo2600/pihole |
| postgres (groundhog2k) | applications/postgresql.nix | https://groundhog2k.github.io/helm-charts/ | 1.6.7 | https://artifacthub.io/packages/helm/groundhog2k/postgres |
| prometheus stack | applications/prometheus.nix | https://prometheus-community.github.io/helm-charts | 83.6.0 | https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack |
| sealed-secrets | applications/sealed-secrets.nix | oci://registry-1.docker.io/bitnamicharts (migrated from bitnami-labs classic repo) | 2.5.19 | https://artifacthub.io/packages/helm/bitnami/sealed-secrets — new post-OCI-migration numbering; frozen at 2.5.19 since the Aug 2025 Bitnami restructuring, no newer tag exists |
| sops-operator | applications/sops.nix | https://isindir.github.io/sops-secrets-operator/ | 0.28.1 | https://artifacthub.io/packages/helm/isindir/sops-secrets-operator |
| tailscale | applications/tailscale.nix | https://pkgs.tailscale.com/helmcharts | 1.98.9 | https://pkgs.tailscale.com/helmcharts/index.yaml |
| homer | applications/homer.nix | https://charts.gabe565.com | 0.13.0 | https://artifacthub.io/packages/helm/gabe565/homer |
| argo-events | applications/argo-events.nix | https://argoproj.github.io/argo-helm | 2.4.21 | https://artifacthub.io/packages/helm/argo/argo-events |

### Deferred — needs review before upgrading

These have newer versions available but involve major or breaking changes. Review release notes before upgrading.

| Service | File | Current | Available | Notes |
|---------|------|---------|-----------|-------|
| kube-prometheus-stack | applications/prometheus.nix | 83.6.0 | 86.1.0 | CRD changes likely; review upgrade docs |
| keycloak | applications/keycloak.nix | 24.1.0 | 25.2.0 | Major bitnami chart version |
| kyverno | applications/kyverno.nix | 3.4.4 | 3.8.1 | Significant policy engine changes |
| spark | applications/spark.nix | 9.3.5 | 10.0.3 | Major version, breaking config changes |
| lldap | applications/lldap.nix | 0.4.2 | 0.6.4 | Check LDAP schema migrations |
| opentelemetry-collector | applications/opentelemetry-collector.nix | 0.107.0 | 0.158.0 | Large version jump; verify config compatibility |
| argo-workflows | applications/argo-workflows.nix | 11.1.10 | unclear | Bitnami renumbered (OCI: ~1.1.x); verify repo migration |
| rustfs | applications/rustfs.nix | 0.0.90 | 0.6.0 | Large jump; still beta software |
| immich (chart) | applications/immich.nix | 0.12.0 | 0.13.1 | **Build-blocked, not just review**: chart ≥0.13 pulls in bjw-s-labs common-library schema validation that fetches `raw.githubusercontent.com` during `helm template`, which fails under Nix's sandboxed/offline build. Needs a workaround (e.g. schema-validation skip flag) before it can be bumped at all |

### Unchecked (internal or niche charts)

| Service | File | Repo | Version |
|---------|------|------|---------|
| calibre | applications/calibre.nix | https://geek-cookbook.github.io/charts/ | 8.4.2 |
| lldap | applications/lldap.nix | https://djjudas21.github.io/charts/ | 0.4.2 |
| marquez | applications/marquez.nix | https://charts.ilum.cloud | 0.42.0 |
| metabase | (moved to up-to-date above) | | |
| mindsdb | applications/mindsdb.nix | (check ArtifactHub) | 0.1.0 |
| mssql | applications/mssql.nix | (check ArtifactHub) | 1.2.3 |
| openldap | applications/openldap.nix | https://charts.rock8s.com | 4.1.1 |
| satisfactory | applications/satisfactory.nix | https://schich.tel/helm-charts | 0.3.2 |
| sqlpad | applications/sqlpad.nix | (check ArtifactHub) | 0.1.0 |

---

## Helm charts via `nixhelm` flake

These are **not** pinned in application files — they track the `nixhelm` flake input. Update by running:

```bash
nix flake update nixhelm
```

- argocd
- cert-manager
- forgejo
- grafana
- loki
- longhorn
- metallb
- promtail
- traefik
