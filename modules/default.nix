{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./alice-bitcoin
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
    ./postgresql
    ./redis
    ./sealed-secrets
  ];
}
