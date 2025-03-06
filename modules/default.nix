{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./forgejo
    ./minio
    ./sealed-secrets
  ];
}
