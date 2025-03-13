{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./cloudbeaver
    ./forgejo
    ./lldap
    ./metabase
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
