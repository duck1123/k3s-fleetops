{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./airflow
    ./alice-bitcoin
    ./alice-specter
    # ./argo-events
    # ./argo-workflows
    # ./authentik
    # ./cloudbeaver
    # ./demo
    # ./forgejo
    ./harbor
    # ./homer
    ./minio
    ./mssql
    ./postgresql
    ./sealed-secrets
    # ./tempo
  ];
}
