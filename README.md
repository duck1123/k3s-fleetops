---
runme:
  id: 01J9HAPD89ZH24ER7CPYFPD9FG
  version: v3
---

my cluster

# Setup

## List Tasks

List all the available babashka tasks.

This is the primary home of most develoment commands and will reveal commands not listed here.

```sh {"id":"01J9DFJCFCN3TYYMJHEZJVZZCJ","name":"list-tasks"}
bb tasks
```

## Prepare environment variables

The `.envrc.example` file documents many of the variables available

### Copy Example file

Create an environment config from the example

```sh {"name":"copy-envrc"}
cp .envrc.example .envrc
```

### Allow Environment

Allow the current environment config to be used.

For security, any change to the config must be explicitly whitelisted.
Refer to direnv for mor information

```sh {"name":"allow-direnv"}
direnv allow
```

## Age Keys

### Restore existing key

If you already have a keepass database set up in a way identical to what I have,
this will prepare that key for a new environment.

```sh {"name":"restore-age-key"}
export KEEPASS_DB_PATH="${HOME}/keepass/passwords.kdbx"
export SECRET_PATH="/Kubernetes/Age-key"
mkdir -p ~/.config/sops/age
keepassxc-cli show -s -a Password ${KEEPASS_DB_PATH?} ${SECRET_PATH?} > ~/.config/sops/age/keys.txt
```

### Create New Key

Create a private key for securing secrets

```sh {"name":"create-age-key"}
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

This will fail if the file has already been created

## Register Git hooks

This ensures all generated yaml is up to date on commit

This only applies to legacy edn-based config

```sh {"name":"setup-git-hooks"}
bb apply-git-hooks
```

## Secrets

This assumes that you have placed the files tls.crt and tls.key at the root of
the directory

All secrets are encrypted with that key

Secrets are ultimately stored in a Keepass database. The `create-sealed-secrets`
command will read the `secrets.edn` file which describes the mappings between
entries in that keepass database and
secret to be encrypted.

All secrets must live in the **encrypted** file `secrets.enc.yaml` at the project root. The old unencrypted `secrets/secrets.yaml` file is not used or supported.

### Creating and editing secrets

You can edit in place (no plaintext file on disk):

```sh
sops secrets.enc.yaml
# or: bb edit-secrets
```

Or decrypt to a file, edit, then encrypt back (plaintext exists only while you edit):

```sh
bb decrypt
# edit secrets/secrets.yaml, then:
bb encrypt
```

To create the encrypted file from scratch (e.g. from Keepass or another source), produce a YAML file, encrypt it with sops, and save as `secrets.enc.yaml`; do not keep an unencrypted `secrets/secrets.yaml` in the repo or in normal use.

### Using secrets when running commands

Any command that needs secrets must be run via the decrypt-to-temp script, which sets `DECRYPTED_SECRET_FILE` for the duration of the command:

```sh
./scripts/with-decrypted-secrets.sh bb switch-charts
# or
./scripts/with-decrypted-secrets.sh nix build .#nixidyEnvs.x86_64-linux.dev.activationPackage --impure --no-link --print-out-paths
```

The script decrypts `secrets.enc.yaml` to a temporary file, sets `DECRYPTED_SECRET_FILE`, runs your command, then removes the temp file so no decrypted copy is left on disk.

# Build

Compile all edn templates to yaml

```sh {"name":"build-code","excludeFromRunAll":"true","id":"01J9DFM8AX7SNGCJJK6XCCV3G3","interactive":"false",}
bb build
```

# K3D Setup

## Registry

Create a k3d registry for storing localally-built dev images

```sh {"name":"create-registry","id":"01J9HAPD89ZH24ER7CP99BVFM4"}
bbg k3d-create-registry
```

## Cluster

Create a k3d cluster

```sh {"name":"create-cluster","id":"01J9HAPD89ZH24ER7CPE4916TR"}
bbg k3d-create
```

See https://github.com/duck1123/dotfiles

# Other

### Check Pod Status

Wait until all pods are running or completed

```sh {"name":"get-pods","id":"01J9EFNB7W63FD7K94XHHQB0Z9"}
kubectl get pods -A
```

## Argo CD

### Install

https://argo-cd.readthedocs.io/en/stable/getting_started/

#### Add Repo

Register Argo Helm Repo

```sh {"name":"add-argo-helm","id":"01JBT0MF6SEC8NMMCZW17AYQEC"}
helm repo add argo https://argoproj.github.io/argo-helm
```

#### Create Namespace

Create namespace for argocd

```sh {"name":"create-argo-namespace","id":"01JBT0MF6SEC8NMMCZW3PFPEJD"}
kubectl create namespace argocd
```

### Install Helm Chart

Load ArgoCD helm chart

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

Fetch the default argocd password. This will be used to log in the first time.

```sh {"id":"01J9HAPD89ZH24ER7CPMKQ1FJW","name":"get-initial-password"}
argocd admin initial-password -n argocd
```

### Forward ports

Forward argocd interface ports.

Untill the main application installs the ingress controllers, the only way to
access the argocd interface is by forwarding the ports.

```sh {"background":"true","id":"01J9HAPD89ZH24ER7CPRARMG51","interactive":"false","name":"forward-argocd-ports"}
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

https://localhost:8080/

### Apply master app

Registers the `00-master` Application with argocd.

This will kick off argo installing all the other resources.

```sh {"id":"01J9HAPD89ZH24ER7CPSBSYNH3","name":"apply-master-application"}
bb apply-master-application
```

#### Create letsencrypt provider

Create cluster issuer record.

This will cause any ingress with the appropriate annotations to obtain a
certificate from letsencrypt

This must be done after the cert-manager crds have been installed

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

Create a secret from the keypair

```sh {"id":"01J9HAPD89ZH24ER7CPX4JV20M","name":"install-sealed-key"}
bb install-sealed-key
```

#### Mark key as active

Flag sealed secret key as active

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

# Inspect

## Argo Workflows

### Read token

Read argo workflow token from secret

```sh {"name": "read-token"}
echo "Bearer $(kubectl -n argo-workflows get secret duck.service-account-token -o=jsonpath='{.data.token}' | base64 --decode)"
```

# Generate CRD

Generate nixidy schemas from CRDs

```sh {"name": "generate-crds"}
nix run .#generate
```

# Build charts

Compile Nixidy config to YAML manifests

```sh {"name": "build-charts"}
nixidy build .#dev
```
