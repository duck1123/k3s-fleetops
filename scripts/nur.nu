# -*- mode: nushell -*-

# ─── PostgreSQL helpers ──────────────────────────────────────────────────────

const PG_NS = "postgresql"
const PG_SECRET = "postgresql-password"
const PG_USER = "postgres"
const PG_PORT = "5432"

def pg-pod [] {
  let pod = (
    ^kubectl get pods -n $PG_NS -l "app.kubernetes.io/name=postgres"
      -o jsonpath='{.items[0].metadata.name}'
    | str trim
  )
  if ($pod | is-empty) {
    error make {msg: $"Could not find PostgreSQL pod in namespace ($PG_NS)"}
  }
  $pod
}

def pg-password [] {
  (
    ^kubectl get secret $PG_SECRET -n $PG_NS -o jsonpath='{.data.adminPassword}'
    | ^base64 -d
    | str trim
  )
}

def pg-databases [pod: string, password: string] {
  (
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
      psql -h localhost -U $PG_USER -p $PG_PORT -t -A
      -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;"
      postgres
    | lines
    | each { str trim }
    | where { |it| $it | is-not-empty }
  )
}

# ─── Build & deploy ──────────────────────────────────────────────────────────

# Post-process already-generated manifests (fixups for nixidy hardcoded behaviours)
export def "nur post-process-manifests" [] {
  let script_path = (
    ^nom-build --no-link --expr '(import <nixpkgs> {}).callPackage ./lib/postProcessManifests.nix {}'
    | str trim
  )
  run-external $"($script_path)/bin/post-process-manifests"
}

# Build the nixidy activation package without applying it (like `nixos-rebuild build`)
export def "nur build" [--show-trace, --fallback] {
  let trace_args = if $show_trace { ["--show-trace"] } else { [] }
  let fallback_args = if $fallback { ["--fallback"] } else { [] }
  (
    ^./scripts/with-decrypted-secrets.sh
      nom build
      .#nixidyEnvs.x86_64-linux.dev.activationPackage
      --impure --no-link --print-out-paths
      ...$trace_args
      ...$fallback_args
    | str trim
  )
}

# Activate a built activation package's output (rsyncs manifests/dev, writes sops secrets, post-processes)
def switch-activation-package [drv_path: string] {
  # nixidy's activate step rsyncs its build output over manifests/dev with
  # --delete; it doesn't know SopsSecret files exist, so it wipes them all on
  # every run. Snapshot them first so write-sops-secrets.sh can tell which
  # ones actually changed instead of re-encrypting everything unconditionally.
  let secrets_backup = (^mktemp -d | str trim)
  if ("manifests/dev" | path exists) {
    cp --recursive manifests/dev $"($secrets_backup)/dev"
  }
  run-external $"($drv_path)/activate"
  with-env {SOPS_SECRETS_REFERENCE_DIR: $"($secrets_backup)/dev"} {
    ./scripts/write-sops-secrets.sh
  }
  rm --recursive --force $secrets_backup
  nur post-process-manifests
}

# Full pipeline: build, then switch (generate manifests, post-process, write to manifests/dev/, activate)
export def "nur switch" [--show-trace, --fallback] {
  let drv_path = nur build --show-trace=$show_trace --fallback=$fallback
  switch-activation-package $drv_path
}

# CI shorthand — same as switch
export def "nur ci" [] {
  nur switch
}

# Format all .nix files using nixfmt
export def "nur format" [] {
  ^find . -name '*.nix' | lines | each { |f| ^nixfmt $f; null } | ignore
}

# Register git hooks for this repo
export def "nur apply-git-hooks" [] {
  ^git config core.hooksPath .githooks
}

# ─── Static site previews ──────────────────────────────────────────────────

# Convention: a previewable app is an npm/Vite project at applications/<name>-site/
# (see applications/duck1123-site/), built into a flake package
# (modules/pkgs/<name>-site.nix) and served via nix-csi in
# applications/<name>/default.nix. `nur preview <name>` runs it with Vite's own
# dev server — no cluster/nix-csi involved — so any future app dropped in under
# that same applications/<name>-site/ layout gets a local preview for free.

# Run an npm/Vite site app's local dev server (installs deps on first run)
export def "nur preview" [
  name: string   # App name, e.g. "duck1123" for applications/duck1123-site/
] {
  let dir = $"applications/($name)-site"
  if not ($dir | path exists) {
    error make {msg: $"No ($dir) found. Expected an npm/Vite project there — see applications/duck1123-site/ for the pattern."}
  }
  if not ($"($dir)/node_modules" | path exists) {
    print $"Installing dependencies in ($dir)..."
    ^npm --prefix $dir install
  }
  ^npm --prefix $dir run dev
}

# ─── App management ──────────────────────────────────────────────────────────

# Every app name registered in applications/default.nix's imports list, so this
# always matches whatever's actually wired into the cluster.
def "nu-complete apps" [] {
  (
    open --raw applications/default.nix
    | lines
    | each { str trim }
    | where {|line| $line | str starts-with './' }
    | each {|line| $line | str replace --all --regex '^\./|\.nix$' '' }
    | uniq
    | sort
  )
}

# List every app name accepted by `nur apps restart` (one per line)
export def "nur apps list" [] {
  nu-complete apps | str join "\n" | print
}

# Restart an app's pod(s) — rolls its Deployment (falling back to StatefulSet) in
# the namespace of the same name, which is the mkArgoApp default and covers the
# common single-workload case (see applications/duck1123/default.nix). Apps with
# a non-default namespace or several workloads (Helm charts, nix-csi) aren't
# resolved here — restart those manually with kubectl.
export def "nur apps restart" [
  name: string   # App name — see `nur apps list`
] {
  if not ($name in (nu-complete apps)) {
    error make {msg: $"Unknown app ($name). Run `nur apps list` to see valid names."}
  }

  if (^kubectl get deployment $name -n $name | complete).exit_code == 0 {
    ^kubectl rollout restart $"deployment/($name)" -n $name
    ^kubectl rollout status $"deployment/($name)" -n $name
    return
  }

  if (^kubectl get statefulset $name -n $name | complete).exit_code == 0 {
    ^kubectl rollout restart $"statefulset/($name)" -n $name
    ^kubectl rollout status $"statefulset/($name)" -n $name
    return
  }

  error make {
    msg: $"No Deployment or StatefulSet named ($name) found in namespace ($name). ($name) may use a non-default namespace or ship multiple workloads \(Helm chart, nix-csi\) — restart it manually with kubectl."
  }
}

# ─── Secrets ─────────────────────────────────────────────────────────────────

# Edit encrypted secrets in-place (no plaintext file written)
export def "nur secrets edit" [] {
  ^sops secrets.enc.yaml
}

# Decrypt secrets to secrets.yaml (plaintext — do not commit)
export def "nur secrets decrypt" [] {
  (^sops --decrypt secrets.enc.yaml | save -f secrets.yaml)
  print "Decrypted to secrets.yaml — do not commit this file"
}

# Encrypt secrets.yaml back to secrets.enc.yaml
export def "nur secrets encrypt" [] {
  (^sops --encrypt secrets.yaml | save -f secrets.enc.yaml)
  print "Encrypted to secrets.enc.yaml"
}

# ─── AutoKuma / kuma-cli ─────────────────────────────────────────────────────

const AUTOKUMA_NS = "autokuma"
const AUTOKUMA_SECRET = "autokuma-kuma-credentials"
const UPTIME_KUMA_NS = "uptime-kuma"
const UPTIME_KUMA_INGRESS = "uptime-kuma"

def kuma-cli-config-path []: nothing -> string {
  let base = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  $"($base)/kuma/config.toml"
}

# Write ~/.config/kuma/config.toml from the cluster: uptime-kuma's ingress
# host for `url`, and the same SOPS-managed credentials autokuma itself uses
# (secret ($AUTOKUMA_SECRET) in namespace ($AUTOKUMA_NS)) for `username`/`password`.
# Run this once (and again after rotating the password) so `kuma` (kuma-cli)
# works without passing --url/--username/--password on every invocation.
export def "nur kuma-cli config" [] {
  let host = (
    ^kubectl get ingress $UPTIME_KUMA_INGRESS -n $UPTIME_KUMA_NS
      -o jsonpath='{.spec.rules[0].host}'
    | str trim
  )
  if ($host | is-empty) {
    error make {msg: $"Could not find ($UPTIME_KUMA_INGRESS) ingress in namespace ($UPTIME_KUMA_NS)"}
  }

  let username = (
    ^kubectl get secret $AUTOKUMA_SECRET -n $AUTOKUMA_NS -o jsonpath='{.data.USERNAME}'
    | ^base64 -d
  )
  let password = (
    ^kubectl get secret $AUTOKUMA_SECRET -n $AUTOKUMA_NS -o jsonpath='{.data.PASSWORD}'
    | ^base64 -d
  )
  if ($username | is-empty) or ($password | is-empty) {
    error make {msg: (
      $"Secret ($AUTOKUMA_SECRET) in namespace ($AUTOKUMA_NS) has no USERNAME/PASSWORD yet. "
      + "Set services.autokuma.kuma.username/password from secrets.autokuma.* "
      + "(nur secrets edit), then nur switch, before running this."
    )}
  }

  let path = (kuma-cli-config-path)
  mkdir ($path | path dirname)
  (
    {
      url: $"https://($host)/",
      username: $username,
      password: $password,
    }
    | to toml
    | save -f $path
  )
  ^chmod 600 $path
  print $"Wrote ($path)"
}

# ─── ArgoCD ──────────────────────────────────────────────────────────────────

# Download latest stable ArgoCD install manifest to infra-manifests/argocd/install.yaml
export def "nur argocd update-manifest" [] {
  mkdir infra-manifests/argocd
  print "Fetching latest stable ArgoCD manifest..."
  (
    http get "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    | save -f infra-manifests/argocd/install.yaml
  )
  print "Done. Commit infra-manifests/argocd/install.yaml to pin the version."
}

# Install or upgrade ArgoCD into the cluster (safe to re-run)
export def "nur argocd install" [] {
  if not ("infra-manifests/argocd/install.yaml" | path exists) {
    print "install.yaml not found, downloading..."
    nur argocd update-manifest
  }
  ^kubectl apply --server-side --force-conflicts -k infra-manifests/argocd/
  print "Waiting for argocd-server rollout..."
  ^kubectl rollout status deployment/argocd-server -n argocd --timeout=120s
  print "ArgoCD install complete"
}

# Register 00-master app with ArgoCD (triggers full sync)
export def "nur argocd apply-master" [] {
  (^jet -i edn -o yaml < infra-manifests/00-master.edn | ^kubectl apply -f -)
}

# Force an immediate ArgoCD reconcile instead of waiting on its poll interval
# (see docs/deployment-workflow.md) -- unlike `apply-master`, this doesn't
# re-apply anything, it just tells ArgoCD to re-diff against git right now.
# With no name, refreshes every Application (00-master and all its children);
# pass one to target just that app, e.g. `nur argocd refresh ditto-relay`.
export def "nur argocd refresh" [name?: string] {
  if ($name | is-empty) {
    ^kubectl annotate application -n argocd --all argocd.argoproj.io/refresh=hard --overwrite
  } else {
    ^kubectl annotate application -n argocd $name argocd.argoproj.io/refresh=hard --overwrite
  }
}

# ─── Port-forwarding ─────────────────────────────────────────────────────────

# Port-forward ArgoCD UI to localhost:8080
export def "nur forward argocd" [] {
  ^kubectl port-forward svc/argocd-server -n argocd 8080:443
}

# Expose Traefik dashboard on localhost:9000
export def "nur forward traefik" [] {
  let pod = (^kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name | str trim)
  ^kubectl port-forward $pod 9000:9000
}

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

# List PostgreSQL databases and their sizes
export def "nur postgres list" [] {
  let pod = (pg-pod)
  let password = (pg-password)
  print $"Namespace: ($PG_NS) | Pod: ($pod)"
  print ""
  (
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
      psql -h localhost -U $PG_USER -p $PG_PORT -t -A -F","
      -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;"
      postgres
    | lines
    | where { |it| $it | is-not-empty }
    | each { |line|
      let parts = ($line | split row ",")
      {name: ($parts | first | str trim), size: ($parts | last | str trim)}
    }
  )
}

# List available PostgreSQL backups on the postgresql-backups PVC
export def "nur postgres list-backups" [] {
  let pod_name = "postgresql-backup-lister"
  let pod_spec = {
    apiVersion: "v1"
    kind: "Pod"
    metadata: {name: $pod_name, namespace: $PG_NS}
    spec: {
      restartPolicy: "Never"
      containers: [{
        name: "lister"
        image: "pgvector/pgvector:pg17"
        command: ["/bin/bash", "-c", "ls -lht /backups/postgresql-backup-*.sql.gz 2>/dev/null || echo 'No backups found'"]
        volumeMounts: [{name: "backups", mountPath: "/backups"}]
      }]
      volumes: [{name: "backups", persistentVolumeClaim: {claimName: "postgresql-backups"}}]
    }
  }
  $pod_spec | to yaml | ^kubectl apply -f -
  ^kubectl -n $PG_NS wait --for=condition=Ready pods $pod_name --timeout=60s
  ^kubectl -n $PG_NS logs $pod_name
  ^kubectl -n $PG_NS delete pods $pod_name --ignore-not-found=true
}

# Backup PostgreSQL databases (omit --database to backup all)
export def "nur postgres backup" [
  --database: string = ""
  --output-dir: string = "./backups/postgresql"
] {
  let pod = (pg-pod)
  let password = (pg-password)
  let timestamp = (date now | format date '%Y%m%d_%H%M%S')
  mkdir $output_dir

  let dbs = if ($database | is-empty) {
    pg-databases $pod $password
  } else {
    [$database]
  }

  print $"=== PostgreSQL Backup ==="
  print $"Namespace: ($PG_NS) | Pod: ($pod)"
  print $"Output: ($output_dir) | Timestamp: ($timestamp)"
  print ""

  for db in $dbs {
    print $"Backing up: ($db)"
    let base = $"($output_dir)/($db)_($timestamp)"

    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        pg_dump -h localhost -U $PG_USER -p $PG_PORT
        --clean --if-exists --create --format=plain --no-owner --no-privileges $db
      | ^gzip
      | save --raw -f $"($base).sql.gz"
    )
    print $"  ✓ ($base).sql.gz"

    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        pg_dump -h localhost -U $PG_USER -p $PG_PORT
        --clean --if-exists --create --format=custom --no-owner --no-privileges $db
      | save --raw -f $"($base).custom"
    )
    print $"  ✓ ($base).custom"
  }

  print ""
  print $"=== Backup Complete: ($output_dir) ==="
  ls $output_dir | sort-by modified -r | first 10
}

# Restore PostgreSQL from a backup — local file or bare PVC filename
export def "nur postgres restore" [
  backup_file: string       # Local path (.sql, .sql.gz, .custom) or PVC filename (no slash)
  --database: string = ""   # Target database; inferred from filename if omitted
  --recreate                # Drop and recreate the target database before restore
] {
  # Bare filename with no slash and file absent locally → restore from PVC via Job
  if (not ($backup_file | path exists)) and (not ($backup_file | str contains "/")) and (
    ($backup_file | str ends-with ".sql.gz") or ($backup_file | str ends-with ".sql")
  ) {
    let job_name = $"postgresql-restore-(date now | format date '%s')"
    let restore_cmd = $"set -e
echo 'Restoring from /backups/($backup_file)'
gunzip -c /backups/($backup_file) | PGPASSWORD=\"$PGPASSWORD\" psql -h postgresql.($PG_NS) -U ($PG_USER) -d postgres
echo 'Restore completed successfully.'"
    let job_spec = {
      apiVersion: "batch/v1"
      kind: "Job"
      metadata: {name: $job_name, namespace: $PG_NS}
      spec: {
        ttlSecondsAfterFinished: 300
        template: {
          spec: {
            restartPolicy: "Never"
            containers: [{
              name: "restore"
              image: "pgvector/pgvector:pg17"
              command: ["/bin/bash", "-c", $restore_cmd]
              env: [{
                name: "PGPASSWORD"
                valueFrom: {secretKeyRef: {name: $PG_SECRET, key: "adminPassword"}}
              }]
              volumeMounts: [{name: "backups", mountPath: "/backups"}]
            }]
            volumes: [{name: "backups", persistentVolumeClaim: {claimName: "postgresql-backups"}}]
          }
        }
      }
    }
    print $"=== PostgreSQL Restore from PVC: ($backup_file) ==="
    $job_spec | to yaml | ^kubectl apply -f -
    print $"Job: ($job_name)"
    print $"Monitor: kubectl logs -n ($PG_NS) -f job/($job_name)"
    ^kubectl wait --for=condition=complete $"job/($job_name)" -n $PG_NS --timeout=600s
    print "=== Restore Complete ==="
    return
  }

  if not ($backup_file | path exists) {
    error make {msg: $"Backup file not found: ($backup_file)"}
  }

  let pod = (pg-pod)
  let password = (pg-password)
  let basename = ($backup_file | path basename)

  let db_name = if ($database | is-not-empty) {
    $database
  } else {
    let m = ($basename | parse --regex '^(?P<name>[^_]+)_\d{8}_\d{6}')
    if ($m | is-empty) {
      error make {msg: $"Cannot infer database name from '($basename)' — pass --database"}
    }
    $m | first | get name
  }

  print $"=== PostgreSQL Restore ==="
  print $"Namespace: ($PG_NS) | Pod: ($pod)"
  print $"File: ($backup_file) | Target DB: ($db_name)"
  print ""

  if $recreate {
    print "Dropping existing database..."
    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        psql -h localhost -U $PG_USER -p $PG_PORT
        -c $"DROP DATABASE IF EXISTS \"($db_name)\";" postgres
    )
    print ""
  }

  if ($backup_file | str ends-with ".custom") {
    print "Restoring from custom format..."
    ^kubectl cp $backup_file $"($PG_NS)/($pod):/tmp/restore.custom"
    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        pg_restore -h localhost -U $PG_USER -p $PG_PORT
        --clean --if-exists --create --no-owner --no-privileges -d postgres /tmp/restore.custom
    )
    ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.custom
  } else if ($backup_file | str ends-with ".sql.gz") {
    print "Restoring from gzipped SQL dump..."
    let tmp_sql = (^mktemp --suffix=.sql | str trim)
    (^gzip -dc $backup_file | save -f $tmp_sql)
    ^kubectl cp $tmp_sql $"($PG_NS)/($pod):/tmp/restore.sql"
    rm $tmp_sql
    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        psql -h localhost -U $PG_USER -p $PG_PORT -f /tmp/restore.sql postgres
    )
    ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.sql
  } else if ($backup_file | str ends-with ".sql") {
    print "Restoring from SQL dump..."
    ^kubectl cp $backup_file $"($PG_NS)/($pod):/tmp/restore.sql"
    (
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
        psql -h localhost -U $PG_USER -p $PG_PORT -f /tmp/restore.sql postgres
    )
    ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.sql
  } else {
    error make {msg: $"Unsupported format: ($backup_file) — expected .sql, .sql.gz, or .custom"}
  }

  print ""
  print $"=== Restore Complete: ($db_name) ==="
  (
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)"
      psql -h localhost -U $PG_USER -p $PG_PORT -c '\l' postgres
  )
}

# ─── MariaDB ──────────────────────────────────────────────────────────────────

# List available MariaDB backups on the mariadb-backups PVC
export def "nur mariadb list-backups" [] {
  let namespace = "mariadb"
  let pod_name = "mariadb-backup-lister"
  let pod_spec = {
    apiVersion: "v1"
    kind: "Pod"
    metadata: {name: $pod_name, namespace: $namespace}
    spec: {
      restartPolicy: "Never"
      containers: [{
        name: "lister"
        image: "bitnami/mariadb:latest"
        command: ["/bin/bash", "-c", "ls -lh /backups/*.sql.gz 2>/dev/null || echo 'No backups found'"]
        volumeMounts: [{name: "backups", mountPath: "/backups"}]
      }]
      volumes: [{name: "backups", persistentVolumeClaim: {claimName: "mariadb-backups"}}]
    }
  }
  $pod_spec | to yaml | ^kubectl apply -f -
  ^kubectl -n $namespace wait --for=condition=Ready pods $pod_name --timeout=60s
  ^kubectl -n $namespace logs $pod_name
  ^kubectl -n $namespace delete pods $pod_name --ignore-not-found=true
}

# Restore MariaDB from a backup file on the PVC (omit --backup-file to be prompted)
export def "nur mariadb restore" [--backup-file: string = ""] {
  let namespace = "mariadb"
  let backup_filename = if ($backup_file | is-empty) {
    nur mariadb list-backups
    input "Enter backup filename (e.g., mariadb-backup-20250101_020000.sql.gz): "
  } else {
    $backup_file
  }

  let job_name = $"mariadb-restore-(date now | format date '%s')"
  let restore_cmd = $"set -e
echo 'Starting restore from: ($backup_filename)'
echo 'WARNING: This will replace all existing databases!'
gunzip -c /backups/($backup_filename) | mysql -h mariadb.mariadb -u root -p\"$MARIADB_ROOT_PASSWORD\"
echo 'Restore completed successfully!'"

  let job_spec = {
    apiVersion: "batch/v1"
    kind: "Job"
    metadata: {name: $job_name, namespace: $namespace}
    spec: {
      ttlSecondsAfterFinished: 300
      template: {
        spec: {
          restartPolicy: "Never"
          containers: [{
            name: "restore"
            image: "bitnami/mariadb:latest"
            command: ["/bin/bash", "-c", $restore_cmd]
            env: [{
              name: "MARIADB_ROOT_PASSWORD"
              valueFrom: {secretKeyRef: {name: "mariadb-password", key: "mariadb-root-password"}}
            }]
            volumeMounts: [{name: "backups", mountPath: "/backups"}]
          }]
          volumes: [{name: "backups", persistentVolumeClaim: {claimName: "mariadb-backups"}}]
        }
      }
    }
  }

  $job_spec | to yaml | ^kubectl apply -f -
  print $"Restore job: ($job_name)"
  print $"Monitor: kubectl logs -n ($namespace) -f job/($job_name)"
}

# ─── Sealed secrets ──────────────────────────────────────────────────────────

# Upload sealed-secrets TLS keypair (tls.crt + tls.key must exist in cwd)
export def "nur sealed-secrets install-key" [] {
  ^kubectl -n sealed-secrets create secret tls imported-secret --cert=tls.crt --key=tls.key
}

# Mark uploaded sealed-secrets key as active
export def "nur sealed-secrets apply-label" [] {
  ^kubectl -n sealed-secrets label secret imported-secret sealedsecrets.bitnami.com/sealed-secrets-key=active
}

# Delete the sealed-secrets controller pod (forces key reload)
export def "nur sealed-secrets delete-controller" [] {
  ^kubectl -n sealed-secrets delete pod -l name=sealed-secrets-controller
}
