{ config, secrets, ... }:
{
  services.immich = {
    enable = true;

    databaseTarget = "postgresql";
    database = {
      inherit (secrets.immich.database) password username;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs.enable = false;

    hostAffinity = "nixmini";

    # Temporarily scaled to 0 while the library PVC is swapped to its pinned
    # equivalent (see applications/immich.nix) -- avoids a live pod holding
    # the old PVC and blocking its deletion. Revert to 1 once the new pinned
    # PVC is Bound.
    replicas = 0;

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
