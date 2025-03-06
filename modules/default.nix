{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./forgejo
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
