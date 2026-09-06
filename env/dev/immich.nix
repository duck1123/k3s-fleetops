{ config, secrets, ... }:
{
  services.immich = {
    enable = true;

    adminApiKey = secrets.immich.adminApiKey;

    databaseTarget = "postgresql";
    database = {
      inherit (secrets.immich.database) password username;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs.enable = false;

    hostAffinity = "nixmini";

    externalLibrary = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Photos";
    };

    monitoring.autokuma.enable = true;
    redis = {
      inherit (secrets.immich.redis) password;
      host = "redis.redis";
      port = 6379;
      dbIndex = 0;
    };

    storageClassName = "longhorn";
  };
}
