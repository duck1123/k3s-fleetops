#!/usr/bin/env sh

helm pull oci://code.forgejo.org/forgejo-helm/forgejo --version 11.0.3
helm pull oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.2.3
