{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./authentik
    ./cloudbeaver
    ./forgejo
    ./homer
    ./lldap
    ./metabase
    ./minio
    ./mssql
    ./postgresql
    ./redis
    ./sealed-secrets
  ];
}
