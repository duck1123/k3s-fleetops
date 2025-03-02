{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./forgejo
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
