#!/usr/bin/env sh

helm pull oci://code.forgejo.org/forgejo-helm/forgejo --version 11.0.3
helm pull oci://registry-1.docker.io/bitnamicharts/jupyterhub --version 8.1.5
helm pull oci://registry-1.docker.io/bitnamicharts/keycloak --version 24.1.0
helm pull oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.2.3
helm pull oci://registry-1.docker.io/bitnamicharts/spark --version 9.3.5
