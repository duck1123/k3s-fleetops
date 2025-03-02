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
    ./cloudbeaver
    ./demo
    ./forgejo
    ./harbor
    ./homer
    ./keycloak
    ./minio
    ./mssql
    ./postgresql
    ./redis
    ./sealed-secrets
    ./sqlpad
    ./tempo
  ];
}
