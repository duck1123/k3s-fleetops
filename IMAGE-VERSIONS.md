# Image & Chart Version Management

This document records all explicitly pinned container images and Helm chart versions, plus the process for checking and updating them. Update this file whenever versions change.

**Last full check: 2026-09-07**

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
| nocodb | applications/nocodb.nix | nocodb/nocodb | 2026.08.2 | https://hub.docker.com/r/nocodb/nocodb/tags |
| paperless-ngx | applications/paperless-ngx.nix | ghcr.io/paperless-ngx/paperless-ngx | 3.1.3 | https://github.com/paperless-ngx/paperless-ngx/releases |
| radarr | env/dev/radarr.nix | linuxserver/radarr | 6.3.0.10514-ls315 | https://hub.docker.com/r/linuxserver/radarr/tags |
| sonarr | env/dev/sonarr.nix | linuxserver/sonarr | 4.0.19.2979-ls323 | https://hub.docker.com/r/linuxserver/sonarr/tags |
| tdarr | env/dev/tdarr.nix | ghcr.io/haveagitgat/tdarr | 2.86.01 | https://github.com/HaveAGitGat/Tdarr (GHCR tags are authoritative; GitHub Releases page is stale) |
| kavita | applications/kavita.nix | linuxserver/kavita | v0.9.1.4-ls123 | https://hub.docker.com/r/linuxserver/kavita/tags — this release line addresses CVE-2026-47202, prioritized |
| mealie | applications/mealie.nix, env/dev/mealie.nix | ghcr.io/mealie-recipes/mealie | v3.25.1 | https://github.com/mealie-recipes/mealie/releases |
| romm | applications/romm.nix | ghcr.io/rommapp/romm | 5.2.0 | https://github.com/rommapp/romm/releases |
| bookorbit | applications/bookorbit.nix | ghcr.io/bookorbit/bookorbit | 1.3.0 (not bumped — see below) | https://github.com/bookorbit/bookorbit/pkgs/container/bookorbit — v2.9.0 available; jumps a major version with several releases since pinning, review changelog before bumping |
| hivemq | applications/hivemq.nix | hivemq/hivemq-ce | 2026.5 | https://hub.docker.com/r/hivemq/hivemq-ce/tags |
| postgres init | applications/immich.nix | docker.io/postgres | 17.11 | https://hub.docker.com/_/postgres/tags |
| pgvector | applications/postgresql.nix | pgvector/pgvector | pg17 (floating) | https://hub.docker.com/r/pgvector/pgvector/tags |
| busybox | various (init containers) | busybox | 1.38 | https://hub.docker.com/_/busybox/tags |
| trilium | applications/trilium.nix | triliumnext/trilium | v0.105.0 | https://github.com/TriliumNext/Trilium/releases |
| hass-AiDot | applications/home-assistant.nix | toxuin/hass-AiDot (git tag, not an image) | v1.2.0 | https://github.com/toxuin/hass-AiDot/releases |
| opensearch | applications/ditto-relay.nix | opensearchproject/opensearch | 2.19.6 | https://hub.docker.com/r/opensearchproject/opensearch/tags |

**Floating images** (no pinning needed — these always pull latest/stable):
Many applications use `:latest`, `:stable`, or a floating major tag (e.g. `redis:8-alpine`, `louislam/uptime-kuma:1`).
These self-update on pod restart and don't require manual tracking.

---

## Helm charts via `downloadHelmChart`

Charts with explicit version pins and SHA-256 hashes.

### Up to date

| Service | File | Repo | Version | ArtifactHub / Source |
|---------|------|------|---------|----------------------|
| authentik | applications/authentik.nix | https://charts.goauthentik.io/ | 2026.8.1 | https://artifacthub.io/packages/helm/goauthentik/authentik |
| cloudbeaver | applications/cloudbeaver.nix | https://avistotelecom.github.io/charts/ | 1.1.7 | https://artifacthub.io/packages/helm/avisto/cloudbeaver — no chart release since May 2025, this is still latest |
| immich | applications/immich.nix | oci://ghcr.io/immich-app/immich-charts | 0.12.0 | https://artifacthub.io/packages/helm/immich/immich |
| kite | applications/kite.nix | https://zxh326.github.io/kite | 0.15.0 | https://github.com/kite-org/kite (image repo moved zxh326→kite-org; Helm repo URL still resolves as-is) |
| mariadb | applications/mariadb.nix | oci://registry-1.docker.io/bitnamicharts (classic charts.bitnami.com repo 403s now) | 27.0.8 | https://artifacthub.io/packages/helm/bitnami/mariadb — free-tier image is `bitnami/mariadb:latest` only, no immutable tag; chart appVersion label is cosmetic since we pin `image` ourselves |
| memos | applications/memos.nix | https://charts.gabe565.com | 0.17.0 | https://artifacthub.io/packages/helm/gabe565/memos — still latest |
| metabase | applications/metabase.nix | https://pmint93.github.io/helm-charts | 2.27.6 | https://artifacthub.io/packages/helm/pmint93/metabase |
| n8n | applications/n8n.nix | https://community-charts.github.io/helm-charts | 1.24.38 | https://artifacthub.io/packages/helm/community-charts/n8n — chart stayed on major 1.x despite the large minor jump; app version now 2.37.10, worth a changelog skim |
| pihole | applications/pihole.nix | https://mojo2600.github.io/pihole-kubernetes/ | 2.38.0 | https://artifacthub.io/packages/helm/mojo2600/pihole — still latest |
| postgres (groundhog2k) | applications/postgresql.nix | https://groundhog2k.github.io/helm-charts/ | 1.6.8 | https://artifacthub.io/packages/helm/groundhog2k/postgres |
| prometheus stack | applications/prometheus.nix | https://prometheus-community.github.io/helm-charts | 83.6.0 | https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack |
| sops-operator | applications/sops.nix | https://isindir.github.io/sops-secrets-operator/ | 0.28.1 | https://artifacthub.io/packages/helm/isindir/sops-secrets-operator — still latest |
| tailscale | applications/tailscale.nix | https://pkgs.tailscale.com/helmcharts | 1.102.3 | https://pkgs.tailscale.com/helmcharts/index.yaml |
| homer | applications/homer.nix | https://charts.gabe565.com | 0.13.0 | https://artifacthub.io/packages/helm/gabe565/homer — still latest |
| argo-events | applications/argo-events.nix | https://argoproj.github.io/argo-helm | 2.4.27 | https://artifacthub.io/packages/helm/argo/argo-events |
| argo-workflows | applications/argo-workflows.nix | https://argoproj.github.io/argo-helm | 2.0.4 | https://artifacthub.io/packages/helm/argo/argo-workflows — migrated off bitnami's frozen/renumbered chart; disabled (`enable = false`), untested against a real deployment |
| keycloak | applications/keycloak.nix | https://codecentric.github.io/helm-charts | 7.3.1 | https://github.com/codecentric/helm-charts/tree/master/charts/keycloakx — migrated off frozen bitnami/keycloak; disabled (`enable = false`), untested against a real deployment |

### Deferred — needs review before upgrading

These have newer versions available but involve major or breaking changes. Review release notes before upgrading.

| Service | File | Current | Available | Notes |
|---------|------|---------|-----------|-------|
| kube-prometheus-stack | applications/prometheus.nix | 83.6.0 | 86.1.0 | CRD changes likely; review upgrade docs |
| kyverno | applications/kyverno.nix | 3.4.4 | 3.8.1 | Significant policy engine changes |
| spark | applications/spark.nix | 9.3.5 | 10.0.3 | Major version, breaking config changes; also still on bitnami/spark (frozen) — no good plain-chart replacement exists post-Bitnami, real alternative is Apache's own spark-kubernetes-operator (Operator+CRDs, different architecture). Disabled and not in active use, left as-is for now |
| lldap | applications/lldap.nix | 0.4.2 | 0.6.4 | Check LDAP schema migrations |
| opentelemetry-collector | applications/opentelemetry-collector.nix | 0.107.0 | 0.158.0 | Large version jump; verify config compatibility |
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
