{ config, secrets, ... }:
{
  services.windmill = {
    enable = true;
    hostAffinity = "nixmini";
    image = "ghcr.io/windmill-labs/windmill-full:latest";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    database = {
      host = "postgresql.postgresql";
      port = 5432;
      name = "windmill";
      username = secrets.windmill.database.username;
      password = secrets.windmill.database.password;
    };

    storageClassName = "longhorn";
    replicas = 1;
  };
}
