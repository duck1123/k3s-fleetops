{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./argo-workflows
    ./cloudbeaver
    ./forgejo
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
