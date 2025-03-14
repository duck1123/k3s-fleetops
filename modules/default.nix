{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./alice-bitcoin
    ./alice-specter
    ./argo-events
    ./argo-workflows
    ./authentik
    ./cloudbeaver
    ./forgejo
    ./harbor
    ./homer
    ./keycloak
    ./lldap
    ./memos
    ./metabase
    ./minio
    ./mssql
    ./opentelemetry-collector
    ./postgresql
    ./redis
    ./sealed-secrets
    ./traefik
  ];
}
