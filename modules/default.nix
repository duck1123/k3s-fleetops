{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./authentik
    ./cloudbeaver
    ./forgejo
    ./homer
    ./keycloak
    ./lldap
    ./metabase
    ./minio
    ./mssql
    ./postgresql
    ./redis
    ./sealed-secrets
  ];
}
