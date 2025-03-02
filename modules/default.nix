{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./airflow
    ./alice-bitcoin
    ./alice-lnd
    ./alice-specter
    ./argo-events
    ./argo-workflows
    ./authentik
    # ./bob-bitcoin
    # ./bob-lnd
    ./cloudbeaver
    ./crossplane-do-provider
    ./demo
    ./dinsro
    ./forgejo
    ./harbor
    ./homer
    ./keycloak
    ./lldap
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
    ./sqlpad
    ./tempo
    ./traefik
  ];
}
