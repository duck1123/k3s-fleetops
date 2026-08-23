{ config, secrets, ... }:
{
  services.immich = {
    enable = true;

    database = {
      inherit (secrets.immich.database) password username;
      host = "postgresql.postgresql";
      port = 5432;
      name = "immich";
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
