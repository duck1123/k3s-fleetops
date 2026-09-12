# -*- mode: nushell -*-

# ─── PostgreSQL helpers ──────────────────────────────────────────────────────

const PG_NS = "postgresql"
const PG_SECRET = "postgresql-password"
const PG_USER = "postgres"
const PG_PORT = "5432"

def pg-pod []: nothing -> string {
  let pod = (
    try {
      ^kubectl get pods -n $PG_NS -l "app.kubernetes.io/name=postgres" -o jsonpath='{.items[0].metadata.name}'
      | str trim
    } catch { |err|
      error make {msg: $"Failed to query PostgreSQL pod: ($err.msg)"}
    }
  )
  if ($pod | is-empty) {
    error make {msg: $"Could not find PostgreSQL pod in namespace ($PG_NS)"}
  }
  $pod
}

def pg-password []: nothing -> string {
  try {
    ^kubectl get secret $PG_SECRET -n $PG_NS -o jsonpath='{.data.adminPassword}'
    | ^base64 -d
    | str trim
  } catch { |err|
    error make {msg: $"Failed to fetch PostgreSQL password: ($err.msg)"}
  }
}

def pg-databases [pod: string, password: string]: nothing -> list<string> {
  try {
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" postgres
    | lines
    | each { str trim }
    | where { |it| $it | is-not-empty }
  } catch { |err|
    error make {msg: $"Failed to list PostgreSQL databases: ($err.msg)"}
  }
}

# ─── Build & deploy ──────────────────────────────────────────────────────────

# Post-process already-generated manifests (fixups for nixidy hardcoded behaviours)
export def "nur post-process-manifests" []: nothing -> nothing {
  let script_path = (
    ^nom-build --no-link --expr '(import <nixpkgs> {}).callPackage ./lib/postProcessManifests.nix {}'
    | str trim
  )
  run-external $"($script_path)/bin/post-process-manifests"
}

# Build the nixidy activation package without applying it (like `nixos-rebuild build`)
export def "nur build" [--show-trace, --fallback]: nothing -> string {
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
def switch-activation-package [drv_path: string]: nothing -> nothing {
  # nixidy's activate step rsyncs its build output over manifests/dev with
  # --delete; it doesn't know SopsSecret files exist, so it wipes them all on
  # every run. Snapshot them first so write-sops-secrets.sh can tell which
  # ones actually changed instead of re-encrypting everything unconditionally.
  let secrets_backup = (^mktemp -d | str trim)
  if ("manifests/dev" | path exists) {
    try {
      cp --recursive manifests/dev $"($secrets_backup)/dev"
    } catch { |err|
      error make {msg: $"Failed to back up manifests/dev: ($err.msg)"}
    }
  }
  run-external $"($drv_path)/activate"
  with-env {SOPS_SECRETS_REFERENCE_DIR: $"($secrets_backup)/dev"} {
    ./scripts/write-sops-secrets.sh
  }
  try {
    rm --recursive --force $secrets_backup
  } catch { |err|
    error make {msg: $"Failed to clean up ($secrets_backup): ($err.msg)"}
  }
  nur post-process-manifests
}

# Push a built store path to the Attic `nixos` cache. Required after any
# change to an application whose applications/<name>/default.nix embeds
# `"${self.packages.<system>.<name>}"` directly into a nix-csi volume's
# per-system storePath (currently duck1123Runtime and windmill-sync-bundle) --
# that pattern has no build recipe for nix-csi to fall back on, so the exact
# path must exist in Attic before the manifest referencing it is pushed, or
# nix-csi has nothing to substitute it from.
export def "nur push-site-cache" [
  name: string   # Flake package name, e.g. "duck1123-site"
]: nothing -> nothing {
  let path = (nom build $".#($name)" --no-link --print-out-paths | str trim)
  attic push nixos $path
}

# Full pipeline: build, then switch (generate manifests, post-process, write to manifests/dev/, activate)
export def "nur switch" [--show-trace, --fallback]: nothing -> nothing {
  let drv_path = nur build --show-trace=$show_trace --fallback=$fallback
  switch-activation-package $drv_path
  nur push-site-cache duck1123-runtime
  nur push-site-cache windmill-sync-bundle
}

# CI shorthand — same as switch
export def "nur ci" []: nothing -> nothing {
  nur lint
  nur switch
}

export def "nur lint" []: nothing -> nothing {
  nur lint nushell
  nur lint nix
}

export def "nur lint nix" [] {
  let response = ^nixpkgs-fmt --check . | complete
  response.exit_code
  if $response.exit_code != 0 {
    print $"nixpkgs-fmt failed with exit code ($response.exit_code)"
    print $response.stderr
    exit $response.exit_code # nu-lint-ignore: exit_only_in_main  
  }
}

# Lint the project
export def "nur lint nushell" [] {
  let response = nu-lint | complete

  # print $response

  if $response.exit_code != 0 {
    print $"Linting failed with exit code ($response.exit_code)"
    print $response.stderr
    exit $response.exit_code # nu-lint-ignore: exit_only_in_main
  }

  # nu-lint always exits 0, even with warnings, so check its summary line ourselves
  let warning_matches = $response.stdout | parse --regex 'Found (?<warnings>\d+) warning'
  let warning_count = if ($warning_matches | is-empty) { 0 } else { $warning_matches | get --optional warnings.0 | default "0" | into int }

  if $warning_count > 0 {
    print -e $response.stdout
    print -e $"nu-lint found ($warning_count) warning\(s\)"
    exit 1 # nu-lint-ignore: exit_only_in_main
  }
}

# Format all .nix files using nixfmt
export def "nur format" []: nothing -> nothing {
  glob **/*.nix | each { |f| ^nixfmt $f; null } | ignore
}

# Register git hooks for this repo
export def "nur apply-git-hooks" []: nothing -> nothing {
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
]: nothing -> nothing {
  let dir = $"applications/($name)-site"
  if not ($dir | path exists) {
    error make {msg: $"No ($dir) found. Expected an npm/Vite project there — see applications/duck1123-site/ for the pattern."}
  }
  if not ($"($dir)/node_modules" | path exists) {
    print $"Installing dependencies in ($dir)..."
    try {
      ^npm --prefix $dir install
    } catch { |err|
      error make {msg: $"npm install failed: ($err.msg)"}
    }
  }
  try {
    ^npm --prefix $dir run dev
  } catch { |err|
    error make {msg: $"npm run dev failed: ($err.msg)"}
  }
}

# ─── App management ──────────────────────────────────────────────────────────

# Every app name registered in applications/default.nix's imports list, so this
# always matches whatever's actually wired into the cluster.
def "nu-complete apps" []: nothing -> list<string> {
  try {
    open --raw applications/default.nix
    | lines
    | each { str trim }
    | where {|line| $line | str starts-with './' }
    | each {|line| $line | str replace --all --regex '^\./|\.nix$' '' }
    | uniq
    | sort
  } catch { |err|
    error make {msg: $"Failed to read applications/default.nix: ($err.msg)"}
  }
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
]: nothing -> nothing {
  if not ($name in (nu-complete apps)) {
    error make {msg: $"Unknown app ($name). Run `nur apps list` to see valid names."}
  }

  if (^kubectl get deployment $name -n $name | complete).exit_code == 0 {
    try {
      ^kubectl rollout restart $"deployment/($name)" -n $name
      ^kubectl rollout status $"deployment/($name)" -n $name
    } catch { |err|
      error make {msg: $"Failed to restart deployment/($name): ($err.msg)"}
    }
    return
  }

  if (^kubectl get statefulset $name -n $name | complete).exit_code == 0 {
    try {
      ^kubectl rollout restart $"statefulset/($name)" -n $name
      ^kubectl rollout status $"statefulset/($name)" -n $name
    } catch { |err|
      error make {msg: $"Failed to restart statefulset/($name): ($err.msg)"}
    }
    return
  }

  error make {
    msg: $"No Deployment or StatefulSet named ($name) found in namespace ($name). ($name) may use a non-default namespace or ship multiple workloads \(Helm chart, nix-csi\) — restart it manually with kubectl."
  }
  return
}

# ─── Secrets ─────────────────────────────────────────────────────────────────

# Edit encrypted secrets in-place (no plaintext file written)
export def "nur secrets edit" []: nothing -> nothing {
  ^sops secrets.enc.yaml
}

# Decrypt secrets to secrets.yaml (plaintext — do not commit)
export def "nur secrets decrypt" [] {
  try {
    ^sops --decrypt secrets.enc.yaml | save --force secrets.yaml
  } catch { |err|
    error make {msg: $"Failed to decrypt secrets: ($err.msg)"}
  }
  print "Decrypted to secrets.yaml — do not commit this file"
}

# Encrypt secrets.yaml back to secrets.enc.yaml
export def "nur secrets encrypt" [] {
  try {
    ^sops --encrypt secrets.yaml | save --force secrets.enc.yaml
  } catch { |err|
    error make {msg: $"Failed to encrypt secrets: ($err.msg)"}
  }
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
    try {
      ^kubectl get ingress $UPTIME_KUMA_INGRESS -n $UPTIME_KUMA_NS -o jsonpath='{.spec.rules[0].host}'
      | str trim
    } catch { |err|
      error make {msg: $"Failed to query ($UPTIME_KUMA_INGRESS) ingress: ($err.msg)"}
    }
  )
  if ($host | is-empty) {
    error make {msg: $"Could not find ($UPTIME_KUMA_INGRESS) ingress in namespace ($UPTIME_KUMA_NS)"}
  }

  let username = (
    try {
      ^kubectl get secret $AUTOKUMA_SECRET -n $AUTOKUMA_NS -o jsonpath='{.data.USERNAME}'
      | ^base64 -d
    } catch { |err|
      error make {msg: $"Failed to read AutoKuma username secret: ($err.msg)"}
    }
  )
  let password = (
    try {
      ^kubectl get secret $AUTOKUMA_SECRET -n $AUTOKUMA_NS -o jsonpath='{.data.PASSWORD}'
      | ^base64 -d
    } catch { |err|
      error make {msg: $"Failed to read AutoKuma password secret: ($err.msg)"}
    }
  )
  if ($username | is-empty) or ($password | is-empty) {
    error make {msg: (
      $"Secret ($AUTOKUMA_SECRET) in namespace ($AUTOKUMA_NS) has no USERNAME/PASSWORD yet. "
      + "Set services.autokuma.kuma.username/password from secrets.autokuma.* "
      + "(nur secrets edit), then nur switch, before running this."
    )}
  }

  let path = (kuma-cli-config-path)
  try {
    mkdir ($path | path dirname)
    (
      {
        url: $"https://($host)/",
        username: $username,
        password: $password,
      }
      | to toml
      | save --force $path
    )
    ^chmod 600 $path
  } catch { |err|
    error make {msg: $"Failed to write ($path): ($err.msg)"}
  }
  print $"Wrote ($path)"
}

# ─── ArgoCD ──────────────────────────────────────────────────────────────────

# Download latest stable ArgoCD install manifest to infra-manifests/argocd/install.yaml
export def "nur argocd update-manifest" [] {
  try {
    mkdir infra-manifests/argocd
  } catch { |err|
    error make {msg: $"Failed to create infra-manifests/argocd: ($err.msg)"}
  }
  print "Fetching latest stable ArgoCD manifest..."
  try {
    (
      http get "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
      | save --force infra-manifests/argocd/install.yaml
    )
  } catch { |err|
    error make {msg: $"Failed to download ArgoCD manifest: ($err.msg)"}
  }
  print "Done. Commit infra-manifests/argocd/install.yaml to pin the version."
}

# Install or upgrade ArgoCD into the cluster (safe to re-run)
export def "nur argocd install" [] {
  if not ("infra-manifests/argocd/install.yaml" | path exists) {
    print "install.yaml not found, downloading..."
    nur argocd update-manifest
  }
  try {
    ^kubectl apply --server-side --force-conflicts -k infra-manifests/argocd/
    print "Waiting for argocd-server rollout..."
    ^kubectl rollout status deployment/argocd-server -n argocd --timeout=120s
  } catch { |err|
    error make {msg: $"ArgoCD install failed: ($err.msg)"}
  }
  print "ArgoCD install complete"
}

# Register 00-master app with ArgoCD (triggers full sync)
export def "nur argocd apply-master" []: nothing -> nothing {
  try {
    (^jet -i edn -o yaml < infra-manifests/00-master.edn | ^kubectl apply -f -)
  } catch { |err|
    error make {msg: $"Failed to apply 00-master: ($err.msg)"}
  }
}

# Force an immediate ArgoCD reconcile instead of waiting on its poll interval
# (see docs/deployment-workflow.md) -- unlike `apply-master`, this doesn't
# re-apply anything, it just tells ArgoCD to re-diff against git right now.
# With no name, refreshes every Application (00-master and all its children);
# pass one to target just that app, e.g. `nur argocd refresh ditto-relay`.
export def "nur argocd refresh" [name?: string]: nothing -> nothing {
  try {
    if ($name | is-empty) {
      ^kubectl annotate application -n argocd --all argocd.argoproj.io/refresh=hard --overwrite
    } else {
      ^kubectl annotate application -n argocd $name argocd.argoproj.io/refresh=hard --overwrite
    }
  } catch { |err|
    error make {msg: $"Failed to refresh ArgoCD application\(s\): ($err.msg)"}
  }
}

# Trigger an actual ArgoCD sync, not just a refresh -- a refresh only recomputes
# the diff against git, it doesn't apply anything or run PostSync hooks. A hook
# Job (e.g. postgresql-init-databases, deleted after HookSucceeded) only re-runs
# on a real sync. Uses `argocd`'s --core mode, which talks to the k8s API
# directly via the local kubeconfig context -- no port-forward/login needed.
# With no name, syncs every Application; pass one to target just that app,
# e.g. `nur argocd sync bookorbit`.
export def "nur argocd sync" [name?: string]: nothing -> nothing {
  if ($name | is-empty) {
    let apps = (
      try {
        ^kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'
        | str trim
        | split row " "
      } catch { |err|
        error make {msg: $"Failed to list ArgoCD applications: ($err.msg)"}
      }
    )
    ^argocd app sync ...$apps --core
  } else {
    ^argocd app sync $name --core
  }
}

# ─── Port-forwarding ─────────────────────────────────────────────────────────

# Port-forward ArgoCD UI to localhost:8080
export def "nur forward argocd" []: nothing -> nothing {
  try {
    ^kubectl port-forward svc/argocd-server -n argocd 8080:443
  } catch { |err|
    error make {msg: $"Port-forward failed: ($err.msg)"}
  }
}

# Expose Traefik dashboard on localhost:9000
export def "nur forward traefik" []: nothing -> nothing {
  let pod = (
    try {
      ^kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name | str trim
    } catch { |err|
      error make {msg: $"Failed to find traefik pod: ($err.msg)"}
    }
  )
  try {
    ^kubectl port-forward $pod 9000:9000
  } catch { |err|
    error make {msg: $"Port-forward failed: ($err.msg)"}
  }
}

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

# List PostgreSQL databases and their sizes
export def "nur postgres list" []: nothing -> table {
  let pod = (pg-pod)
  let password = (pg-password)
  print $"Namespace: ($PG_NS) | Pod: ($pod)"
  print ""
  try {
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -t -A -F"," -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;" postgres
    | lines
    | where { |it| $it | is-not-empty }
    | each { |line|
      let parts = ($line | split row ",")
      {name: ($parts | first | str trim), size: ($parts | last | str trim)}
    }
  } catch { |err|
    error make {msg: $"Failed to list databases: ($err.msg)"}
  }
}

# List available PostgreSQL backups on the postgresql-backups PVC
export def "nur postgres list-backups" []: nothing -> nothing {
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
  try {
    $pod_spec | to yaml | ^kubectl apply -f -
    ^kubectl -n $PG_NS wait --for=condition=Ready pods $pod_name --timeout=60s
    ^kubectl -n $PG_NS logs $pod_name
    ^kubectl -n $PG_NS delete pods $pod_name --ignore-not-found=true
  } catch { |err|
    error make {msg: $"Failed to list PostgreSQL backups: ($err.msg)"}
  } | ignore
}

# Backup PostgreSQL databases (omit --database to backup all)
export def "nur postgres backup" [
  --database: string = ""
  --output-dir: string = "./backups/postgresql"
]: nothing -> table {
  let pod = (pg-pod)
  let password = (pg-password)
  let timestamp = (date now | format date '%Y%m%d_%H%M%S')
  try {
    mkdir $output_dir
  } catch { |err|
    error make {msg: $"Failed to create ($output_dir): ($err.msg)"}
  }

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

    try {
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" pg_dump -h localhost -U $PG_USER -p $PG_PORT --clean --if-exists --create --format=plain --no-owner --no-privileges $db
      | ^gzip
      | save --raw --force $"($base).sql.gz"
    } catch { |err|
      error make {msg: $"Backup of ($db) \(plain\) failed: ($err.msg)"}
    }
    print $"  ✓ ($base).sql.gz"

    try {
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" pg_dump -h localhost -U $PG_USER -p $PG_PORT --clean --if-exists --create --format=custom --no-owner --no-privileges $db
      | save --raw --force $"($base).custom"
    } catch { |err|
      error make {msg: $"Backup of ($db) \(custom\) failed: ($err.msg)"}
    }
    print $"  ✓ ($base).custom"
  }

  print ""
  print $"=== Backup Complete: ($output_dir) ==="
  try {
    ls $output_dir | sort-by modified -r | first 10
  } catch { |err|
    error make {msg: $"Failed to list ($output_dir): ($err.msg)"}
  }
}

# Restore PostgreSQL from a backup — local file or bare PVC filename
export def "nur postgres restore" [
  backup_file: string       # Local path (.sql, .sql.gz, .custom) or PVC filename (no slash)
  --database: string = ""   # Target database; inferred from filename if omitted
  --recreate                # Drop and recreate the target database before restore
]: nothing -> nothing {
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
    try {
      $job_spec | to yaml | ^kubectl apply -f -
      print $"Job: ($job_name)"
      print $"Monitor: kubectl logs -n ($PG_NS) -f job/($job_name)"
      ^kubectl wait --for=condition=complete $"job/($job_name)" -n $PG_NS --timeout=600s
    } catch { |err|
      error make {msg: $"PVC restore job failed: ($err.msg)"}
    }
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
    try {
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -c $"DROP DATABASE IF EXISTS \"($db_name)\";" postgres
    } catch { |err|
      error make {msg: $"Failed to drop ($db_name): ($err.msg)"}
    }
    print ""
  }

  if ($backup_file | str ends-with ".custom") {
    print "Restoring from custom format..."
    try {
      ^kubectl cp $backup_file $"($PG_NS)/($pod):/tmp/restore.custom"
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" pg_restore -h localhost -U $PG_USER -p $PG_PORT --clean --if-exists --create --no-owner --no-privileges -d postgres /tmp/restore.custom
      ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.custom
    } catch { |err|
      error make {msg: $"Restore from ($backup_file) failed: ($err.msg)"}
    }
  } else if ($backup_file | str ends-with ".sql.gz") {
    print "Restoring from gzipped SQL dump..."
    let tmp_sql = (^mktemp --suffix=.sql | str trim)
    try {
      ^gzip -dc $backup_file | save --force $tmp_sql
      ^kubectl cp $tmp_sql $"($PG_NS)/($pod):/tmp/restore.sql"
    } catch { |err|
      error make {msg: $"Failed to stage ($backup_file) for restore: ($err.msg)"}
    }
    try {
      rm $tmp_sql
    } catch { |err|
      error make {msg: $"Failed to clean up ($tmp_sql): ($err.msg)"}
    }
    try {
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -f /tmp/restore.sql postgres
      ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.sql
    } catch { |err|
      error make {msg: $"Restore from ($backup_file) failed: ($err.msg)"}
    }
  } else if ($backup_file | str ends-with ".sql") {
    print "Restoring from SQL dump..."
    try {
      ^kubectl cp $backup_file $"($PG_NS)/($pod):/tmp/restore.sql"
      ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -f /tmp/restore.sql postgres
      ^kubectl exec -n $PG_NS $pod -- rm -f /tmp/restore.sql
    } catch { |err|
      error make {msg: $"Restore from ($backup_file) failed: ($err.msg)"}
    }
  } else {
    error make {msg: $"Unsupported format: ($backup_file) — expected .sql, .sql.gz, or .custom"}
  }

  print ""
  print $"=== Restore Complete: ($db_name) ==="
  try {
    ^kubectl exec -n $PG_NS $pod -- env $"PGPASSWORD=($password)" psql -h localhost -U $PG_USER -p $PG_PORT -c '\l' postgres
  } catch { |err|
    error make {msg: $"Failed to list databases after restore: ($err.msg)"}
  }
}

# ─── MariaDB ──────────────────────────────────────────────────────────────────

# List available MariaDB backups on the mariadb-backups PVC
export def "nur mariadb list-backups" []: nothing -> nothing {
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
  try {
    $pod_spec | to yaml | ^kubectl apply -f -
    ^kubectl -n $namespace wait --for=condition=Ready pods $pod_name --timeout=60s
    ^kubectl -n $namespace logs $pod_name
    ^kubectl -n $namespace delete pods $pod_name --ignore-not-found=true
  } catch { |err|
    error make {msg: $"Failed to list MariaDB backups: ($err.msg)"}
  } | ignore
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

  try {
    $job_spec | to yaml | ^kubectl apply -f -
  } catch { |err|
    error make {msg: $"Failed to start MariaDB restore job: ($err.msg)"}
  }
  print $"Restore job: ($job_name)"
  print $"Monitor: kubectl logs -n ($namespace) -f job/($job_name)"
}
