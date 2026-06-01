# Image & Chart Version Management

This document records all explicitly pinned container images and Helm chart versions, plus the process for checking and updating them. Update this file whenever versions change.

**Last full check: 2026-06-01**

---

## How to update a container image

1. Find the `default = "image:tag"` line in `applications/<name>.nix` (or the `image = "..."` override in `env/dev.nix`).
2. Replace the tag with the new version.
3. Run `nur switch-charts` to regenerate and apply manifests.

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
# 4. Run nur switch-charts
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
| nocodb | applications/nocodb.nix | nocodb/nocodb | 2026.05.2 | https://hub.docker.com/r/nocodb/nocodb/tags |
| radarr | env/dev.nix | linuxserver/radarr | 6.1.1.10360-ls304 | https://hub.docker.com/r/linuxserver/radarr/tags |
| sonarr | env/dev.nix | linuxserver/sonarr | 4.0.17.2952-ls312 | https://hub.docker.com/r/linuxserver/sonarr/tags |
| kavita | applications/kavita.nix | linuxserver/kavita | v0.9.0.2-ls110 | https://hub.docker.com/r/linuxserver/kavita/tags |
| mealie | applications/mealie.nix | ghcr.io/mealie-recipes/mealie | v3.19.2 | https://github.com/mealie-recipes/mealie/releases |
| romm | applications/romm.nix | ghcr.io/rommapp/romm | 4.8.1 | https://github.com/rommapp/romm/releases |
| hivemq | applications/hivemq.nix | hivemq/hivemq-ce | 2026.5 | https://hub.docker.com/r/hivemq/hivemq-ce/tags |
| specter | applications/specter.nix | lncm/specter-desktop | v2.1.1 | https://github.com/lncm/docker-specter-desktop/releases |
| postgres init | applications/immich.nix | docker.io/postgres | 17.10 | https://hub.docker.com/_/postgres/tags |
| pgvector | applications/postgresql.nix | pgvector/pgvector | pg17 (floating) | https://hub.docker.com/r/pgvector/pgvector/tags |
| busybox | various (init containers) | busybox | 1.36 | https://hub.docker.com/_/busybox/tags |

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
| immich | applications/immich.nix | oci://ghcr.io/immich-app/immich-charts | 0.12.0 | https://artifacthub.io/packages/helm/immich/immich |
| memos | applications/memos.nix | https://charts.gabe565.com | 0.17.0 | https://artifacthub.io/packages/helm/gabe565/memos |
| metabase | applications/metabase.nix | https://pmint93.github.io/helm-charts | 2.26.0 | https://artifacthub.io/packages/helm/pmint93/metabase |
| minio | applications/minio.nix | https://charts.bitnami.com/bitnami | 17.0.21 | https://artifacthub.io/packages/helm/bitnami/minio |
| n8n | applications/n8n.nix | https://community-charts.github.io/helm-charts | 1.16.44 | https://artifacthub.io/packages/helm/community-charts/n8n |
| pihole | applications/pihole.nix | https://mojo2600.github.io/pihole-kubernetes/ | 2.35.0 | https://artifacthub.io/packages/helm/mojo2600/pihole |
| postgres (groundhog2k) | applications/postgresql.nix | https://groundhog2k.github.io/helm-charts/ | 1.6.2 | https://artifacthub.io/packages/helm/groundhog2k/postgres |
| prometheus stack | applications/prometheus.nix | https://prometheus-community.github.io/helm-charts | 83.6.0 | https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack |
| sealed-secrets | applications/sealed-secrets.nix | https://bitnami-labs.github.io/sealed-secrets | 2.18.6 | https://artifacthub.io/packages/helm/bitnami-labs/sealed-secrets |
| sops-operator | applications/sops.nix | https://isindir.github.io/sops-secrets-operator/ | 0.25.3 | https://artifacthub.io/packages/helm/isindir/sops-secrets-operator |
| tailscale | applications/tailscale.nix | https://pkgs.tailscale.com/helmcharts | 1.98.4 | https://pkgs.tailscale.com/helmcharts/index.yaml |
| homer | applications/homer.nix | https://charts.gabe565.com | 0.13.0 | https://artifacthub.io/packages/helm/gabe565/homer |
| argo-events | applications/argo-events.nix | https://argoproj.github.io/argo-helm | 2.4.21 | https://artifacthub.io/packages/helm/argo/argo-events |
| mariadb | applications/mariadb.nix | https://charts.bitnami.com/bitnami | 25.0.8 | https://artifacthub.io/packages/helm/bitnami/mariadb |

### Deferred — needs review before upgrading

These have newer versions available but involve major or breaking changes. Review release notes before upgrading.

| Service | File | Current | Available | Notes |
|---------|------|---------|-----------|-------|
| kube-prometheus-stack | applications/prometheus.nix | 83.6.0 | 86.1.0 | CRD changes likely; review upgrade docs |
| keycloak | applications/keycloak.nix | 24.1.0 | 25.2.0 | Major bitnami chart version |
| kyverno | applications/kyverno.nix | 3.4.4 | 3.8.1 | Significant policy engine changes |
| spark | applications/spark.nix | 9.3.5 | 10.0.3 | Major version, breaking config changes |
| airflow | applications/airflow.nix | 1.15.0 | 1.21.0 | Review DAG compatibility |
| lldap | applications/lldap.nix | 0.4.2 | 0.6.4 | Check LDAP schema migrations |
| opentelemetry-collector | applications/opentelemetry-collector.nix | 0.107.0 | 0.158.0 | Large version jump; verify config compatibility |
| argo-workflows | applications/argo-workflows.nix | 11.1.10 | unclear | Bitnami renumbered (OCI: ~1.1.x); verify repo migration |
| rustfs | applications/rustfs.nix | 0.0.90 | 0.6.0 | Large jump; still beta software |

### Unchecked (internal or niche charts)

| Service | File | Repo | Version |
|---------|------|------|---------|
| alice-bitcoin | applications/alice-bitcoin.nix | https://chart.kronkltd.net/ | 0.2.3 |
| alice-lnd | applications/alice-lnd.nix | https://chart.kronkltd.net/ | 0.3.9 |
| adventureworks | applications/adventureworks.nix | (internal) | 0.1.0 |
| cloudbeaver | applications/cloudbeaver.nix | (check ArtifactHub) | 1.0.10 |
| calibre | applications/calibre.nix | https://geek-cookbook.github.io/charts/ | 8.4.2 |
| kite | applications/kite.nix | https://zxh326.github.io/kite | 0.5.0 |
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
