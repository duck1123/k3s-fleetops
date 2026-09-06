{ config, secrets, ... }:
{
  # ../../applications/immich.nix
  services.immich = {
    adminApiKey = secrets.immich.adminApiKey;

    database = {
      inherit (secrets.immich.database) password username;
    };

    databaseTarget = "postgresql";
    enable = true;

    externalLibrary = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Photos";
    };

    hostAffinity = "nixmini";
    ingress.tls.enable = true;
    ingressProvider = "traefik-lan";
    monitoring.autokuma.enable = true;
    nfs.enable = false;

    redis = {
      inherit (secrets.immich.redis) password;
      host = "redis.redis";
      port = 6379;
      dbIndex = 0;
    };

    storageClassName = "longhorn";
  };
}
