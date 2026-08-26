{ config, secrets, ... }:
{
  services.windmill = {
    enable = false;
    # hostAffinity = "nixmini";
    image = "ghcr.io/windmill-labs/windmill-full:latest";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    databaseTarget = "postgresql";
    database = {
      inherit (secrets.windmill.database) username password;
    };

    storageClassName = "longhorn";
    replicas = 1;
  };
}
