{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./alice-bitcoin
    ./alice-specter
    ./argo-events
    ./argo-workflows
    ./authentik
    ./cloudbeaver
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
    ./opentelemetry-collector
    ./postgresql
    ./redis
    ./sealed-secrets
    ./traefik
  ];
}
