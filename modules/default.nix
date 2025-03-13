{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./cloudbeaver
    ./forgejo
    ./metabase
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
