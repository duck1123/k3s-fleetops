{ ... }: {
  imports = [
    ./adventureworks
    ./airflow
    ./alice-bitcoin
    ./alice-lnd
    ./alice-specter
    ./argocd
    ./argo-events
    ./argo-workflows
    ./authentik
    # ./bob-bitcoin
    # ./bob-lnd
    ./cert-manager
    ./cloudbeaver
    ./crossplane
    ./demo
    ./dinsro
    ./forgejo
    ./harbor
    ./homer
    ./keycloak
    ./kyverno
    ./jupyterhub
    ./lldap
    ./longhorn
    ./memos
    ./metabase
    ./mindsdb
    ./minio
    ./mssql
    ./openldap
    ./opentelemetry-collector
    ./postgresql
    ./redis
    ./sealed-secrets
    ./sops
    ./spark
    ./sqlpad
    ./tempo
    ./traefik
  ];
}
