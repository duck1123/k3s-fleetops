#!/usr/bin/env sh

set -e

helm pull oci://code.forgejo.org/forgejo-helm/forgejo --version 12.5.2
helm pull oci://registry-1.docker.io/bitnamicharts/harbor --version 24.6.0
helm pull oci://ghcr.io/immich-app/immich-charts/immich --version 0.10.3
helm pull oci://registry-1.docker.io/bitnamicharts/jupyterhub --version 8.1.5
helm pull oci://registry-1.docker.io/bitnamicharts/keycloak --version 24.1.0
helm pull oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.27
helm pull oci://registry-1.docker.io/bitnamicharts/spark --version 9.3.5
