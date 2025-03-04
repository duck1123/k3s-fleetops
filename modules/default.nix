{ inputs, ... }: {
  imports = [
    ./adventureworks
    ./argo-events
    ./minio
    ./sealed-secrets
  ];
}
