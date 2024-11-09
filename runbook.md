---
runme:
  id: 01J9HAPD89ZH24ER7CPYFPD9FG
  version: v3
---

# Setup

## Register Git hooks

This ensures all generated yaml is up to date on commit

```sh {"name":"setup-git-hooks"}
bb apply-git-hooks
```

## Secrets

This assumes that you have placed the files tls.crt and tls.key at the root of the directory

All secrets are encrypted with that key

## Registry

```sh {"id":"01J9HAPD89ZH24ER7CP99BVFM4","name":"create-registry"}
bbg k3d-create-registry
```

## Cluster

See https://github.com/duck1123/dotfiles

```sh {"id":"01J9HAPD89ZH24ER7CPE4916TR","name":"create-cluster"}
bbg k3d-create
```

### Check Pod Status

Wait until all pods are running or completed

```sh {"id":"01J9EFNB7W63FD7K94XHHQB0Z9","name":"get-pods"}
kubectl get pods -A
```

## Argo CD

### Install

https://argo-cd.readthedocs.io/en/stable/getting_started/

#### Add Repo

```sh {"id":"01JBT0MF6SEC8NMMCZW17AYQEC"}
helm repo add argo https://argoproj.github.io/argo-helm
```

#### Create Namespace

```sh {"id":"01JBT0MF6SEC8NMMCZW3PFPEJD","name":"create-argo-namespace"}
kubectl create namespace argocd
```

### Install Helm Chart

```sh {"id":"01JBT0MF6SEC8NMMCZW5Y95TD9","name":"install-argocd"}
export DOMAIN="argocd.dev.kronkltd.net"
cat <<EOF | jet -o yaml | helm upgrade argocd argo/argo-cd \
  --install \
  --namespace argocd \
  --version 7.6.12 \
  -f -
{:domain "${DOMAIN?}"
 :configs {:params {"server.insecure" true}}
 :server
 {:ingress
   {:annotations
    {"cert-manager.io/cluster-issuer"           "letsencrypt-prod"
     "ingress.kubernetes.io/force-ssl-redirect" "true"}
    :enabled     true
    :tls         true
    :hostname    "${DOMAIN?}"}}}
EOF
```

### Get password

```sh {"id":"01J9HAPD89ZH24ER7CPMKQ1FJW","name":"get-initial-password"}
argocd admin initial-password -n argocd
```

### Forward ports

```sh {"background":"true","id":"01J9HAPD89ZH24ER7CPRARMG51","interactive":"false","name":"forward-argocd-ports"}
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

https://localhost:8080/

### Apply master app

This registers the `00-master` Application with argocd.

```sh {"id":"01J9HAPD89ZH24ER7CPSBSYNH3","name":"apply-master-application"}
bb apply-master-application
```

#### Create letsencrypt provider

Create cluster issuer record.

This will cause any ingress with the appropriate annotations to obtain a
certificate from letsencrypt

replace EMAIL with your email

```sh {"excludeFromRunAll":"true","id":"01J9EFNB7XD34C8SG0HQSE3CRJ","name":"install-cluster-issuer"}
# Set to an email that will receive certificate expiration notices.
export EMAIL="duck@kronkltd.net"

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

### Install Sealed Key

Ensure that `001-infra` is properly healthy

Ensure that `tls.crt` and `tls.key` have been installed to the root of the directory. (from Keepass)

#### Upload sealed key to server

Creates a secret from the keypair

```sh {"id":"01J9HAPD89ZH24ER7CPX4JV20M","name":"install-sealed-key"}
bb install-sealed-key
```

#### Mark key as active

```sh {"id":"01J9HAPD89ZH24ER7CPY71BQTB","name":"apply-sealed-key-label"}
bb apply-sealed-key-label
```

# Clean Up

## Delete Cluster

Completely destroy dev cluster

```sh {"excludeFromRunAll":"true","id":"01JBT0MF6SEC8NMMCZW8ZPSWA5","name":"delete-cluster"}
k3d cluster delete
```

## Delete Registry

Delete registry for locally-built images

```sh {"excludeFromRunAll":"true","id":"01J9M6SR2R5G8JE646YKSHWZ9T","name":"delete-registry"}
k3d registry delete k3d-myregistry.localtest.me
```
