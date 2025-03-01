{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./airflow
    ./argo-events
    ./argo-workflows
    ./forgejo
    ./harbor
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
  ];
}
