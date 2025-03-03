{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./forgejo
    ./minio
    ./postgresql
    ./sealed-secrets
  ];
}
