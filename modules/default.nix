{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./cloudbeaver
    ./forgejo
    ./homer
    ./lldap
    ./metabase
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
